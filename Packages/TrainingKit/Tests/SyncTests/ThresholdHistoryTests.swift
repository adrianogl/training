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
    @Test func historyRecordsOnlyChanges() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: FakeDataSource(dataDays: nil), container: container, today: { today })

        try await engine.upsertHeartRateZones(zonesDTO(threshold: 160), today: today.adding(days: -2))
        try await engine.upsertHeartRateZones(zonesDTO(threshold: 160), today: today.adding(days: -1))
        try await engine.upsertHeartRateZones(zonesDTO(threshold: 162), today: today)

        let records = try history(in: container)
        #expect(records.map(\.day) == [today.adding(days: -2).iso, today.iso])
        #expect(records.map(\.heartRate) == [160, 162])
        #expect(records.allSatisfy { $0.sport == "DEFAULT" })
    }

    @Test func historyIgnoresMissingThreshold() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: FakeDataSource(dataDays: nil), container: container, today: { today })

        try await engine.upsertHeartRateZones(zonesDTO(threshold: nil), today: today)

        #expect(try history(in: container).isEmpty)
    }

    @Test func thresholdOnDayUsesLatestBefore() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        context.insert(ThresholdHistoryRecord(sport: "running", day: "2026-10-01", heartRate: 158))
        context.insert(ThresholdHistoryRecord(sport: "running", day: "2026-10-20", heartRate: 162))
        context.insert(ThresholdHistoryRecord(sport: "cycling", day: "2026-10-10", heartRate: 150))
        try context.save()

        #expect(try thresholdHeartRate(on: Day(iso: "2026-10-15")!, sport: "running", in: context) == 158)
        #expect(try thresholdHeartRate(on: Day(iso: "2026-10-20")!, sport: "running", in: context) == 162)
        #expect(try thresholdHeartRate(on: Day(iso: "2026-11-01")!, sport: "running", in: context) == 162)
    }

    @Test func thresholdBeforeHistoryUsesOldest() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        context.insert(ThresholdHistoryRecord(sport: "running", day: "2026-10-01", heartRate: 158))
        context.insert(ThresholdHistoryRecord(sport: "running", day: "2026-10-20", heartRate: 162))
        try context.save()

        #expect(try thresholdHeartRate(on: Day(iso: "2025-01-01")!, sport: "running", in: context) == 158)
    }

    @Test func thresholdWithoutHistoryUsesZonesRecord() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        context.insert(HeartRateZonesRecord(sport: "running", lactateThresholdHeartRate: 161))
        try context.save()

        #expect(try thresholdHeartRate(on: today, sport: "running", in: context) == 161)
        #expect(try thresholdHeartRate(on: today, sport: "cycling", in: context) == nil)
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
        context.insert(ThresholdHistoryRecord(sport: "DEFAULT", day: today.adding(days: -5).iso, heartRate: 140))
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
