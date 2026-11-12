import Foundation
import SwiftData
import Testing
@testable import Storage

@Suite struct SchemaV5MigrationTests {
    @Test func v4StoreOpensWithCurrentContainer() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")
        let raceId = UUID()

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: SchemaV4.self),
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(container)
            context.insert(SchemaV4.ActivityRecord(activityId: 505, typeKey: "running", name: "Limiar", start: Date(timeIntervalSince1970: 5_000), distance: 8_000, zoneSeconds: [30, 90, 200, 300, 60], thresholdZoneSeconds: [20, 80, 210, 310, 60], thresholdUsed: 160, scoreValue: 74, scoreKey: "v1|160"))
            context.insert(SchemaV4.RaceRecord(id: raceId, name: "10K", day: "2026-09-01", distance: 10_000, goalSeconds: 2_700, priority: .a, resultActivityId: 505, manuallyUnlinked: true))
            context.insert(SchemaV4.ThresholdHistoryRecord(sport: "running", day: "2026-08-01", heartRate: 160))
            context.insert(SchemaV4.RaceDecisionRecord(activityId: 505, decision: .race))
            context.insert(SchemaV4.HeartRateZonesRecord(zone1Floor: 100, zone2Floor: 120, zone3Floor: 140, zone4Floor: 160, zone5Floor: 175, maxHeartRate: 190, lactateThresholdHeartRate: 170, restingHeartRate: 48))
            try context.save()
        }

        let container = try TrainingSchema.container(url: url)
        let context = ModelContext(container)
        let activity = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.activityId == 505)
        #expect(activity.zoneSeconds == [30, 90, 200, 300, 60])
        #expect(activity.thresholdZoneSeconds == [20, 80, 210, 310, 60])
        #expect(activity.thresholdUsed == 160)
        #expect(activity.scoreValue == 74)
        #expect(activity.scoreKey == "v1|160")
        #expect(activity.fitThresholdHeartRate == nil)
        #expect(activity.watchZoneFloors == [])
        let race = try #require(try context.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(race.id == raceId)
        #expect(race.priorityLevel == .a)
        #expect(race.manuallyUnlinked)
        let history = try #require(try context.fetch(FetchDescriptor<ThresholdHistoryRecord>()).first)
        #expect(history.heartRate == 160)
        let decision = try #require(try context.fetch(FetchDescriptor<RaceDecisionRecord>()).first)
        #expect(decision.raceDecision == .race)
        #expect(try context.fetch(FetchDescriptor<HeartRateZonesRecord>()).first?.lactateThresholdHeartRate == 170)
    }

    @Test func v5StoreReopensWithCurrentContainer() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")

        do {
            let context = ModelContext(try TrainingSchema.container(url: url))
            context.insert(ActivityRecord(activityId: 606, fitThresholdHeartRate: 160, watchZoneFloors: [110, 136, 144, 152, 160]))
            try context.save()
        }

        let context = ModelContext(try TrainingSchema.container(url: url))
        let activity = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.fitThresholdHeartRate == 160)
        #expect(activity.watchZoneFloors == [110, 136, 144, 152, 160])
    }

    @Test func schemaV4IsFrozenWithoutTheNewActivityFields() {
        let v4 = Schema(versionedSchema: SchemaV4.self)
        let activity = v4.entities.first { $0.name == "ActivityRecord" }
        let attributes = Set(activity?.attributes.map(\.name) ?? [])
        #expect(attributes.contains("thresholdUsed"))
        #expect(!attributes.contains("fitThresholdHeartRate"))
        #expect(!attributes.contains("watchZoneFloors"))
    }

    @Test func currentSchemaIsV5() {
        let names = Set(Schema(versionedSchema: SchemaV5.self).entities.map(\.name))
        #expect(names == ["DailyRecord", "ActivityRecord", "RaceRecord", "SyncState", "HeartRateZonesRecord", "ThresholdHistoryRecord", "RaceDecisionRecord"])
        #expect(SchemaV5.versionIdentifier == Schema.Version(5, 0, 0))
        #expect(TrainingMigrationPlan.schemas.last.map(ObjectIdentifier.init) == ObjectIdentifier(SchemaV5.self))
        #expect(TrainingSchema.models.count == 7)
    }
}
