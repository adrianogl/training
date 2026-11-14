import Foundation
import SwiftData
import Testing
@testable import Storage

@Suite struct SchemaV7MigrationTests {
    @Test func currentSchemaIsV7() {
        let names = Set(Schema(versionedSchema: SchemaV7.self).entities.map(\.name))
        #expect(names == ["DailyRecord", "ActivityRecord", "RaceRecord", "SyncState", "HeartRateZonesRecord", "ThresholdHistoryRecord", "RaceDecisionRecord", "GoalRecord"])
        #expect(TrainingMigrationPlan.schemas.last.map(ObjectIdentifier.init) == ObjectIdentifier(SchemaV7.self))
        #expect(TrainingSchema.models.count == 8)
    }

    @Test func v6StoreOpensAsV7AndAcceptsGoals() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")
        let raceId = UUID()

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: SchemaV6.self),
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(container)
            context.insert(SchemaV6.RaceRecord(id: raceId, name: "Meia", day: "2026-11-29", distance: 21_097.5))
            context.insert(SchemaV6.SyncState(firstLoadCompleted: true, readinessVersion: 4))
            try context.save()
        }

        let context = ModelContext(try TrainingSchema.container(url: url))
        #expect(try context.fetch(FetchDescriptor<RaceRecord>()).map(\.id) == [raceId])
        #expect(try context.fetch(FetchDescriptor<SyncState>()).first?.readinessVersion == 4)
        #expect(try context.fetch(FetchDescriptor<GoalRecord>()).isEmpty)
        context.insert(GoalRecord(kind: .time, distanceKm: 10, targetSeconds: 2_400))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<GoalRecord>()).first?.goalKind == .time)
    }
}
