import Foundation
import SwiftData

public enum TrainingSchema {
    public static let models: [any PersistentModel.Type] = SchemaV8.models

    public static func container(inMemory: Bool) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV8.self),
            migrationPlan: TrainingMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        )
    }

    public static func container(url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV8.self),
            migrationPlan: TrainingMigrationPlan.self,
            configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
        )
    }
}
