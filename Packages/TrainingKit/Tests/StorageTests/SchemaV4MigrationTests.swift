import Foundation
import SwiftData
import Testing
@testable import Storage

@Suite struct SchemaV4MigrationTests {
    @Test func v3StoreMigratesToV4() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")
        let raceId = UUID()

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: SchemaV3.self),
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(container)
            context.insert(SchemaV3.ActivityRecord(activityId: 404, typeKey: "running", name: "Tempo", start: Date(timeIntervalSince1970: 4_000), distance: 10_000, zoneSeconds: [60, 120, 300, 200, 40]))
            context.insert(SchemaV3.RaceRecord(id: raceId, name: "10K", day: "2026-07-01", distance: 10_000, goalSeconds: 2_700, priority: .b, resultActivityId: 404, frozenTargetSeconds: 2_650, frozenTargetDay: "2026-06-20"))
            context.insert(SchemaV3.HeartRateZonesRecord(zone1Floor: 100, zone2Floor: 120, zone3Floor: 140, zone4Floor: 160, zone5Floor: 175, maxHeartRate: 190, lactateThresholdHeartRate: 170, restingHeartRate: 48))
            try context.save()
        }

        let container = try TrainingSchema.container(url: url)
        let context = ModelContext(container)
        let activity = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.activityId == 404)
        #expect(activity.distance == 10_000)
        #expect(activity.zoneSeconds == [60, 120, 300, 200, 40])
        #expect(activity.thresholdZoneSeconds == [])
        #expect(activity.thresholdUsed == nil)
        #expect(activity.scoreValue == nil)
        #expect(activity.scoreKey == nil)
        #expect(activity.scoreData == nil)
        let race = try #require(try context.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(race.id == raceId)
        #expect(race.resultActivityId == 404)
        #expect(race.frozenTargetSeconds == 2_650)
        #expect(race.manuallyUnlinked == false)
        let zones = try #require(try context.fetch(FetchDescriptor<HeartRateZonesRecord>()).first)
        #expect(zones.lactateThresholdHeartRate == 170)
        #expect(try context.fetch(FetchDescriptor<ThresholdHistoryRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<RaceDecisionRecord>()).isEmpty)
    }

    @Test func schemaV4ListsSevenModels() {
        let names = Set(Schema(versionedSchema: SchemaV4.self).entities.map(\.name))
        #expect(names == ["DailyRecord", "ActivityRecord", "RaceRecord", "SyncState", "HeartRateZonesRecord", "ThresholdHistoryRecord", "RaceDecisionRecord"])
        #expect(SchemaV4.models.count == 7)
        #expect(TrainingSchema.models.count == 7)
    }

    @Test func newRecordsRoundTrip() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(ThresholdHistoryRecord(sport: "running", day: "2026-05-01", heartRate: 168))
        context.insert(RaceDecisionRecord(activityId: 9, decision: .notRace))
        context.insert(ActivityRecord(activityId: 9, thresholdZoneSeconds: [1, 2, 3, 4, 5], thresholdUsed: 168, scoreValue: 82, scoreKey: "easy", scoreData: Data([7])))
        try context.save()

        let history = try #require(try context.fetch(FetchDescriptor<ThresholdHistoryRecord>()).first)
        #expect(history.sport == "running" && history.day == "2026-05-01" && history.heartRate == 168)
        let decision = try #require(try context.fetch(FetchDescriptor<RaceDecisionRecord>()).first)
        #expect(decision.activityId == 9)
        #expect(decision.raceDecision == .notRace)
        let activity = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.thresholdZoneSeconds == [1, 2, 3, 4, 5])
        #expect(activity.thresholdUsed == 168)
        #expect(activity.scoreValue == 82)
        #expect(activity.scoreKey == "easy")
        #expect(activity.scoreData == Data([7]))
    }
}
