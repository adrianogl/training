import Foundation
import SwiftData
import Testing
@testable import Storage

@Suite struct MigrationTests {
    @Test func v1StoreMigratesToV2() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: SchemaV1.self),
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(container)
            context.insert(SchemaV1.ActivityRecord(activityId: 101, typeKey: "running", name: "Rodagem", start: Date(timeIntervalSince1970: 1_000), distance: 8_000))
            context.insert(SchemaV1.ActivityRecord(activityId: 202, typeKey: "trail_running", name: "Trilha", start: Date(timeIntervalSince1970: 2_000), samplesData: Data([1, 2, 3])))
            for day in ["2026-01-01", "2026-01-02", "2026-01-03"] {
                context.insert(SchemaV1.DailyRecord(day: day, restingHR: 50))
            }
            try context.save()
        }

        let container = try TrainingSchema.container(url: url)
        let context = ModelContext(container)
        let activities = try context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.activityId)]))
        #expect(activities.map(\.activityId) == [101, 202])
        #expect(activities.allSatisfy { $0.processingVersion == 0 })
        #expect(activities.allSatisfy { $0.structureData == nil })
        #expect(activities.allSatisfy { $0.localDay == nil && $0.workoutName == nil && $0.narrativeData == nil })
        #expect(activities[0].distance == 8_000)
        #expect(activities[1].samplesData == Data([1, 2, 3]))
        #expect(try context.fetch(FetchDescriptor<DailyRecord>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<HeartRateZonesRecord>()).isEmpty)
    }

    @Test func v2StoreMigratesToV3() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")
        let raceId = UUID()

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: SchemaV2.self),
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(container)
            context.insert(SchemaV2.ActivityRecord(activityId: 303, typeKey: "running", name: "Longo", start: Date(timeIntervalSince1970: 3_000), distance: 21_000))
            context.insert(SchemaV2.RaceRecord(id: raceId, name: "Meia", day: "2026-06-01", distance: 21_097.5, goalSeconds: 5_400, priority: .a))
            context.insert(SchemaV2.SyncState(firstLoadCompleted: true, resumeDailyFrom: "2026-01-05"))
            try context.save()
        }

        let container = try TrainingSchema.container(url: url)
        let context = ModelContext(container)
        let activity = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.activityId == 303)
        #expect(activity.distance == 21_000)
        #expect(activity.fitTransientFailures == 0)
        let race = try #require(try context.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(race.id == raceId)
        #expect(race.goalSeconds == 5_400)
        #expect(race.priority == "A")
        #expect(race.frozenTargetSeconds == nil)
        #expect(race.frozenTargetDay == nil)
        let state = try #require(try context.fetch(FetchDescriptor<SyncState>()).first)
        #expect(state.firstLoadCompleted)
        #expect(state.resumeDailyFrom == "2026-01-05")
        #expect(state.readinessVersion == 0)
    }

    @Test @MainActor func zonesRecordRoundTrips() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(HeartRateZonesRecord(
            zone1Floor: 100,
            zone2Floor: 120,
            zone3Floor: 140,
            zone4Floor: 160,
            zone5Floor: 175,
            maxHeartRate: 190,
            lactateThresholdHeartRate: 170,
            restingHeartRate: 48
        ))
        try context.save()

        let zones = try context.fetch(FetchDescriptor<HeartRateZonesRecord>())
        #expect(zones.count == 1)
        #expect(zones[0].sport == "running")
        #expect([zones[0].zone1Floor, zones[0].zone2Floor, zones[0].zone3Floor, zones[0].zone4Floor, zones[0].zone5Floor] == [100, 120, 140, 160, 175])
        #expect(zones[0].maxHeartRate == 190)
        #expect(zones[0].lactateThresholdHeartRate == 170)
        #expect(zones[0].restingHeartRate == 48)
    }

    @Test func activityRecordKeepsNewFields() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(ActivityRecord(activityId: 7, localDay: "2026-03-04", processingVersion: 2, workoutName: "Intervalado 6x800", structureData: Data([9]), narrativeData: Data([8])))
        try context.save()

        let activity = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.localDay == "2026-03-04")
        #expect(activity.processingVersion == 2)
        #expect(activity.workoutName == "Intervalado 6x800")
        #expect(activity.structureData == Data([9]))
        #expect(activity.narrativeData == Data([8]))
    }

    @Test func versionedSchemasKeepEntityNames() {
        let v1 = Set(Schema(versionedSchema: SchemaV1.self).entities.map(\.name))
        let v2 = Set(Schema(versionedSchema: SchemaV2.self).entities.map(\.name))
        let v3 = Set(Schema(versionedSchema: SchemaV3.self).entities.map(\.name))
        let v4 = Set(Schema(versionedSchema: SchemaV4.self).entities.map(\.name))
        #expect(v1 == ["DailyRecord", "ActivityRecord", "RaceRecord", "SyncState"])
        #expect(v2 == v1.union(["HeartRateZonesRecord"]))
        #expect(v3 == v2)
        #expect(v4 == v3.union(["ThresholdHistoryRecord", "RaceDecisionRecord"]))
        #expect(Set(Schema(TrainingSchema.models).entities.map(\.name)) == v4)
    }
}
