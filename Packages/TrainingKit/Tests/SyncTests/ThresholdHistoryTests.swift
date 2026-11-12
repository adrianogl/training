import FITReader
import Foundation
import GarminAPI
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let today = Day(iso: "2026-11-08")!

private func zonesDTO(threshold: Int?) -> HRZonesDTO {
    HRZonesDTO(sport: "DEFAULT", zone1Floor: 100, zone2Floor: 120, zone3Floor: 140, zone4Floor: 160, zone5Floor: 175, lactateThresholdHeartRateUsed: threshold)
}

private func history(in container: ModelContainer) throws -> [ThresholdHistoryRecord] {
    try ModelContext(container).fetch(FetchDescriptor<ThresholdHistoryRecord>(sortBy: [SortDescriptor(\.day)]))
}

private func activity(_ id: Int64, in container: ModelContainer) throws -> ActivityRecord {
    try #require(try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == id })).first)
}

@Suite struct ThresholdHistoryTests {
    @Test func zonesSyncNoLongerWritesHistory() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: FakeDataSource(dataDays: nil), container: container, today: { today })

        try await engine.upsertHeartRateZones(zonesDTO(threshold: 160))
        try await engine.upsertHeartRateZones(zonesDTO(threshold: 162))

        #expect(try history(in: container).isEmpty)
        let zones = try ModelContext(container).fetch(FetchDescriptor<HeartRateZonesRecord>())
        #expect(zones.map(\.lactateThresholdHeartRate) == [162])
    }

    @Test func fitThresholdWritesHistoryByRunDay() async throws {
        let fake = FakeDataSource(
            dataDays: nil,
            activities: [
                FakeDataSource.activity(id: 1, typeKey: "running", day: today.adding(days: -1), hour: 18),
                FakeDataSource.activity(id: 2, typeKey: "running", day: today.adding(days: -1), hour: 7),
                FakeDataSource.activity(id: 3, typeKey: "running", day: today.adding(days: -3)),
                FakeDataSource.activity(id: 4, typeKey: "cycling", day: today.adding(days: -2)),
            ],
            fitZips: [
                1: try FITZipBuilder.run(seconds: 300, zoneThreshold: 172),
                2: try FITZipBuilder.run(seconds: 300, zoneThreshold: 171),
                3: try FITZipBuilder.run(seconds: 300, zoneThreshold: 168),
            ]
        )
        await fake.setLactateThreshold(150)
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -4))

        _ = try await engine.run()

        let records = try history(in: container)
        #expect(records.map(\.day) == [today.adding(days: -3).iso, today.adding(days: -1).iso])
        #expect(records.map(\.heartRate) == [168, 172])
        #expect(records.allSatisfy { $0.sport == SyncConstants.fitThresholdSport })
        let run = try activity(3, in: container)
        #expect(run.fitThresholdHeartRate == 168)
        #expect(run.watchZoneFloors == [110, 130, 140, 150, 160])
        #expect(run.thresholdUsed == 168)
        #expect(try activity(1, in: container).fitThresholdHeartRate == 172)
    }

    @Test func reprocessingEarlierRunKeepsLatestRunThreshold() async throws {
        let fake = FakeDataSource(
            dataDays: nil,
            activities: [
                FakeDataSource.activity(id: 1, typeKey: "running", day: today.adding(days: -1), hour: 18),
                FakeDataSource.activity(id: 2, typeKey: "running", day: today.adding(days: -1), hour: 7),
            ],
            fitZips: [
                1: try FITZipBuilder.run(seconds: 300, zoneThreshold: 172),
                2: try FITZipBuilder.run(seconds: 300, zoneThreshold: 171),
            ]
        )
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -2))
        _ = try await engine.run()
        let context = ModelContext(container)
        let early = try #require(try context.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == 2 })).first)
        early.processingVersion = 0
        try context.save()

        let report = try await engine.reprocess(limit: nil)

        #expect(report.reprocessed == 1)
        let records = try history(in: container)
        #expect(records.map(\.day) == [today.adding(days: -1).iso])
        #expect(records.map(\.heartRate) == [172])
    }

    @Test func thresholdOnDayUsesLatestBefore() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: "2026-10-01", heartRate: 158))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: "2026-10-20", heartRate: 162))
        try context.save()

        #expect(try thresholdHeartRate(on: Day(iso: "2026-10-15")!, in: context) == 158)
        #expect(try thresholdHeartRate(on: Day(iso: "2026-10-20")!, in: context) == 162)
        #expect(try thresholdHeartRate(on: Day(iso: "2026-11-01")!, in: context) == 162)
    }

    @Test func thresholdBeforeHistoryUsesOldest() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: "2026-10-01", heartRate: 158))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: "2026-10-20", heartRate: 162))
        try context.save()

        #expect(try thresholdHeartRate(on: Day(iso: "2025-01-01")!, in: context) == 158)
    }

    @Test func timelineIgnoresEndpointRecords() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        context.insert(ThresholdHistoryRecord(sport: "DEFAULT", day: "2026-10-01", heartRate: 140))
        context.insert(ThresholdHistoryRecord(sport: "running", day: "2026-10-02", heartRate: 145))
        context.insert(HeartRateZonesRecord(sport: "DEFAULT", lactateThresholdHeartRate: 161))
        try context.save()

        #expect(try thresholdHeartRate(on: Day(iso: "2026-10-15")!, in: context) == 161)

        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: "2026-10-10", heartRate: 170))
        try context.save()

        #expect(try thresholdHeartRate(on: Day(iso: "2026-10-15")!, in: context) == 170)
    }

    @Test func timelineFallsBackToZonesRecordWithoutFitHistory() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        #expect(try thresholdHeartRate(on: today, in: context) == nil)

        context.insert(HeartRateZonesRecord(sport: "DEFAULT", lactateThresholdHeartRate: 155))
        try context.save()
        #expect(try thresholdHeartRate(on: today, in: context) == 155)

        context.insert(HeartRateZonesRecord(sport: "running", lactateThresholdHeartRate: 161))
        try context.save()
        #expect(try thresholdHeartRate(on: today, in: context) == 161)
        #expect(try runningZonesRecord(in: context)?.sport == "running")
    }

    @Test func thresholdsForManyDaysMatchSingleLookup() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: "2026-10-01", heartRate: 158))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: "2026-10-20", heartRate: 162))
        try context.save()
        let days = ["2025-01-01", "2026-10-15", "2026-10-20", "2026-11-01", "2026-10-15"].compactMap(Day.init(iso:))

        let thresholds = try thresholdHeartRates(on: days, in: context)

        #expect(thresholds.count == 4)
        for day in days {
            #expect(thresholds[day] == (try thresholdHeartRate(on: day, in: context)))
        }
    }

    @Test func processedRunGetsThresholdZoneSeconds() async throws {
        let fake = FakeDataSource(
            dataDays: nil,
            activities: [FakeDataSource.activity(id: 1, typeKey: "running", day: today.adding(days: -1))],
            fitZip: try FITZipBuilder.run(seconds: 900)
        )
        await fake.setLactateThreshold(160)
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -3))

        _ = try await engine.run()

        let run = try activity(1, in: container)
        #expect(run.thresholdUsed == 160)
        #expect(run.thresholdZoneSeconds.count == 5)
        #expect(run.thresholdZoneSeconds[0] > 0)
        #expect(run.thresholdZoneSeconds[3] == 0)
        #expect(run.thresholdZoneSeconds[4] == 0)
        #expect((850...900).contains(run.thresholdZoneSeconds.reduce(0, +)))
    }

    @Test func runWithoutHeartRateKeepsEmpty() async throws {
        let fake = FakeDataSource(
            dataDays: nil,
            activities: [FakeDataSource.activity(id: 1, typeKey: "running", day: today.adding(days: -1))],
            fitZip: try FITZipBuilder.run(seconds: 300, withHeartRate: false)
        )
        await fake.setLactateThreshold(160)
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -3))

        _ = try await engine.run()

        let run = try activity(1, in: container)
        #expect(run.fitProcessed)
        #expect(run.samplesData != nil)
        #expect(run.thresholdZoneSeconds.isEmpty)
    }

    @Test func refreshRecomputesWhenThresholdOfDayChanges() async throws {
        let fake = FakeDataSource(
            dataDays: nil,
            activities: [FakeDataSource.activity(id: 1, typeKey: "running", day: today.adding(days: -2))],
            fitZip: try FITZipBuilder.run(seconds: 900)
        )
        await fake.setLactateThreshold(160)
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -3))
        _ = try await engine.run()
        let before = try activity(1, in: container).thresholdZoneSeconds

        let context = ModelContext(container)
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: today.adding(days: -5).iso, heartRate: 140))
        try context.save()
        _ = try await engine.run()

        let run = try activity(1, in: container)
        #expect(run.thresholdUsed == 140)
        #expect(run.thresholdZoneSeconds != before)
        #expect(run.thresholdZoneSeconds[0] < before[0])
        #expect(await fake.fitCalls == [1])
    }

    @Test func refreshStopsAtLimit() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        let samples = try JSONEncoder().encode((0..<60).map { FITSample(t: Double($0), heartRate: 150) })
        context.insert(HeartRateZonesRecord(sport: "DEFAULT", lactateThresholdHeartRate: 160))
        for id in 1...3 {
            context.insert(ActivityRecord(
                activityId: Int64(id),
                typeKey: "running",
                start: Date(timeIntervalSince1970: 1_790_000_000 + Double(id) * 86_400),
                samplesData: samples,
                fitProcessed: true,
                localDay: today.adding(days: -id).iso
            ))
        }
        try context.save()

        #expect(try refreshThresholdZoneSeconds(in: context, limit: 2) == 2)
        #expect(try refreshThresholdZoneSeconds(in: context, limit: 2) == 1)
        #expect(try refreshThresholdZoneSeconds(in: context, limit: 2) == 0)
        let records = try context.fetch(FetchDescriptor<ActivityRecord>())
        #expect(records.allSatisfy { $0.thresholdUsed == 160 && $0.thresholdZoneSeconds == [0, 0, 59, 0, 0] })
    }
}
