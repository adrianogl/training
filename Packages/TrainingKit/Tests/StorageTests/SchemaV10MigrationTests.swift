import Foundation
import SwiftData
import Testing
@testable import Storage

@Suite struct SchemaV10MigrationTests {
    @Test func v10StoreOpensAsV11WithoutBestEfforts() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: SchemaV10.self),
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(container)
            let record = SchemaV10.ActivityRecord(activityId: 9, typeKey: "running", name: "Ritmo 5 km")
            record.scoreValue = 92
            context.insert(record)
            try context.save()
        }

        let context = ModelContext(try TrainingSchema.container(url: url))
        let activity = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.scoreValue == 92)
        #expect(activity.bestEffortsData == nil)
        #expect(activity.bestEffortsVersion == 0)
    }
}
