import FITReader
import Foundation
import GarminAPI
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let today = Day(iso: "2026-11-08")!

private func makeEngine(_ fake: FakeDataSource, fitLimit: Int? = nil) throws -> (SyncEngine, ModelContainer) {
    let container = try TrainingSchema.container(inMemory: true)
    let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -10), fitLimit: fitLimit)
    return (engine, container)
}

private func records(in container: ModelContainer) throws -> [Int64: ActivityRecord] {
    Dictionary(uniqueKeysWithValues: try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>()).map { ($0.activityId, $0) })
}

private func insertProcessedRuns(_ ids: [Int64], in container: ModelContainer) throws {
    let context = ModelContext(container)
    for (offset, id) in ids.enumerated() {
        let start = ActivityTime.startOfDay(today.adding(days: -(20 + offset))).addingTimeInterval(7 * 3_600)
        context.insert(ActivityRecord(activityId: id, typeKey: "running", start: start, fitProcessed: true))
    }
    try context.save()
}

@Suite struct StructureSyncTests {
    @Test func storesStructureAndVersion() async throws {
        let zip = try FITZipBuilder.structuredRun(seconds: 300)
        let fake = FakeDataSource(dataDays: nil, activities: [FakeDataSource.activity(id: 1, typeKey: "running", day: today)], fitZip: zip)
        let (engine, container) = try makeEngine(fake)

        let report = try await engine.run()

        #expect(report.fitProcessed == 1)
        #expect(report.processedActivityIds == [1])
        let record = try #require(try records(in: container)[1])
        #expect(record.processingVersion == FITReaderConstants.processingVersion)
        #expect(record.processingVersion == 3)
        #expect(record.workoutName == FITZipBuilder.workoutName)
        let stored = try JSONDecoder().decode(WorkoutStructure.self, from: try #require(record.structureData))
        let expected = try FITReader.read(zip: zip).structure
        #expect(stored == expected)
        #expect(stored.prescription?.steps.count == 2)
        #expect(stored.laps.count == 2)
    }

    @Test func reprocessesOldVersionNewestFirst() async throws {
        let fake = FakeDataSource(
            dataDays: nil,
            fitZip: try FITZipBuilder.structuredRun(seconds: 300),
            fitErrors: [12: .rateLimited(path: "\(GarminEndpoints.fitDownloadPathPrefix)/12")]
        )
        let (engine, container) = try makeEngine(fake)
        try insertProcessedRuns([11, 12, 13], in: container)

        let report = try await engine.run()

        #expect(await fake.fitCalls == [11, 12])
        #expect(report.reprocessed == 1)
        #expect(report.fitProcessed == 0)
        #expect(report.processedActivityIds == [11])
        #expect(report.fitStoppedByRateLimit)
        let stored = try records(in: container)
        #expect(stored[11]?.processingVersion == FITReaderConstants.processingVersion)
        #expect(stored[11]?.workoutName == FITZipBuilder.workoutName)
        #expect(stored[12]?.processingVersion == 0)
        #expect(stored[13]?.processingVersion == 0)
        let state = try #require(try ModelContext(container).fetch(FetchDescriptor<SyncState>()).first)
        #expect(state.firstLoadCompleted)
        #expect(state.lastSync != nil)
    }

    @Test func newRunsComeBeforeReprocessing() async throws {
        let activities = [
            FakeDataSource.activity(id: 1, typeKey: "running", day: today.adding(days: -2)),
            FakeDataSource.activity(id: 2, typeKey: "running", day: today.adding(days: -1)),
        ]
        let fake = FakeDataSource(dataDays: nil, activities: activities, fitZip: try FITZipBuilder.run(seconds: 300))
        let (engine, container) = try makeEngine(fake)
        try insertProcessedRuns([21, 22], in: container)
        let context = ModelContext(container)
        context.insert(ActivityRecord(activityId: 23, typeKey: "running", start: .now, fitProcessed: true, processingVersion: FITReaderConstants.processingVersion))
        context.insert(ActivityRecord(activityId: 24, typeKey: "cycling", start: .now, fitProcessed: true))
        try context.save()

        let report = try await engine.run()

        #expect(await fake.fitCalls == [2, 1, 21, 22])
        #expect(report.fitProcessed == 2)
        #expect(report.reprocessed == 2)
        #expect(report.fitStoppedByRateLimit == false)
        #expect(try records(in: container).values.filter { $0.typeKey == "running" }.allSatisfy { $0.processingVersion == FITReaderConstants.processingVersion })
    }

    @Test func respectsFitLimit() async throws {
        let activities = (0..<5).map { FakeDataSource.activity(id: Int64(30 + $0), typeKey: "running", day: today.adding(days: -$0)) }
        let fake = FakeDataSource(dataDays: nil, activities: activities, fitZip: try FITZipBuilder.run(seconds: 300))
        let (engine, _) = try makeEngine(fake, fitLimit: 2)

        let report = try await engine.run()

        #expect(await fake.fitCalls == [30, 31])
        #expect(report.fitProcessed == 2)
    }

    @Test func missingFITLeavesQueue() async throws {
        let activities = [
            FakeDataSource.activity(id: 60, typeKey: "running", day: today),
            FakeDataSource.activity(id: 61, typeKey: "running", day: today.adding(days: -1)),
            FakeDataSource.activity(id: 62, typeKey: "running", day: today.adding(days: -2)),
        ]
        let fake = FakeDataSource(
            dataDays: nil,
            activities: activities,
            fitZip: try FITZipBuilder.run(seconds: 300),
            fitErrors: [60: .client(status: 404, path: "\(GarminEndpoints.fitDownloadPathPrefix)/60"), 61: .server(status: 503)]
        )
        let (engine, container) = try makeEngine(fake, fitLimit: 2)

        _ = try await engine.run()
        _ = try await engine.run()

        #expect(await fake.fitCalls == [60, 61, 61, 62])
        let stored = try records(in: container)
        #expect(stored[60]?.fitProcessed == true)
        #expect(stored[60]?.processingVersion == FITReaderConstants.processingVersion)
        #expect(stored[60]?.structureData == nil)
        #expect(stored[61]?.fitProcessed == false)
        #expect(stored[62]?.fitProcessed == true)
    }

    @Test func persistsZones() async throws {
        let fake = FakeDataSource(dataDays: nil)
        let (engine, container) = try makeEngine(fake)

        _ = try await engine.run()
        _ = try await engine.run()

        let zones = try ModelContext(container).fetch(FetchDescriptor<HeartRateZonesRecord>())
        #expect(zones.count == 1)
        let zone = try #require(zones.first)
        #expect(zone.sport == "DEFAULT")
        #expect([zone.zone1Floor, zone.zone2Floor, zone.zone3Floor, zone.zone4Floor, zone.zone5Floor] == [100, 120, 140, 160, 175])
    }

    @Test func storesLocalDay() async throws {
        let late = ActivityDTO(activityId: 50, activityName: "Noturno", typeKey: "cycling", startTimeLocal: "2026-03-10 23:40:00", distance: 1_000, duration: 600)
        let malformed = ActivityDTO(activityId: 51, typeKey: "cycling", startTimeLocal: "10/03/2026 23:40", distance: 1_000, duration: 600)
        let fake = FakeDataSource(dataDays: nil, activities: [late, malformed])
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: Day(iso: "2026-03-01")!)

        _ = try await engine.run()

        let stored = try records(in: container)
        #expect(stored[50]?.localDay == "2026-03-10")
        #expect(stored[51]?.localDay == nil)
    }

    @Test func backfillsLocalDayFromStart() async throws {
        let fake = FakeDataSource(dataDays: nil)
        let (engine, container) = try makeEngine(fake)
        let start = ActivityTime.startOfDay(Day(iso: "2026-05-04")!).addingTimeInterval(22 * 3_600)
        let context = ModelContext(container)
        context.insert(ActivityRecord(activityId: 60, typeKey: "cycling", start: start))
        context.insert(ActivityRecord(activityId: 61, typeKey: "cycling"))
        context.insert(ActivityRecord(activityId: 62, typeKey: "cycling", start: start, localDay: "2026-05-05"))
        try context.save()

        _ = try await engine.reprocess(limit: nil)

        let stored = try records(in: container)
        #expect(stored[60]?.localDay == "2026-05-04")
        #expect(stored[61]?.localDay == nil)
        #expect(stored[62]?.localDay == "2026-05-05")
    }

    @Test func reprocessRunsOnlyTheQueue() async throws {
        let fake = FakeDataSource(dataDays: today.adding(days: -5)...today, fitZip: try FITZipBuilder.structuredRun(seconds: 300))
        let (engine, container) = try makeEngine(fake)
        try insertProcessedRuns([71, 72, 73], in: container)
        let context = ModelContext(container)
        context.insert(ActivityRecord(activityId: 74, typeKey: "running", start: .now))
        try context.save()

        let report = try await engine.reprocess(limit: 2)

        #expect(await fake.fitCalls == [71, 72])
        #expect(report.reprocessed == 2)
        #expect(report.fitProcessed == 0)
        #expect(report.fitStoppedByRateLimit == false)
        #expect(await fake.froms.isEmpty)
        #expect(await fake.activityPageStarts.isEmpty)
        #expect(await fake.zonesCalls == 0)
        #expect(try ModelContext(container).fetch(FetchDescriptor<SyncState>()).first?.lastSync == nil)
    }
}
