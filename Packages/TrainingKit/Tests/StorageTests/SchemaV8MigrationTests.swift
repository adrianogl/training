import Foundation
import SwiftData
import Testing
@testable import Storage

@Suite struct SchemaV8MigrationTests {
    @Test func currentSchemaIsV8() {
        #expect(TrainingMigrationPlan.schemas.last.map(ObjectIdentifier.init) == ObjectIdentifier(SchemaV8.self))
        #expect(TrainingSchema.models.count == 8)
    }

    @Test func v7StoreOpensAsV8WithoutWeather() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: SchemaV7.self),
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(container)
            context.insert(SchemaV7.ActivityRecord(activityId: 42, typeKey: "running", name: "Rodagem"))
            try context.save()
        }

        let context = ModelContext(try TrainingSchema.container(url: url))
        let activity = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.activityId == 42)
        #expect(activity.runWeather == nil)
        activity.weatherTemperature = 28
        activity.weatherDewPoint = 21
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ActivityRecord>()).first?.weatherEffect?.stress == .heat)
    }
}
