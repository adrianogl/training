import SwiftData

public enum TrainingSchema {
    public static let models: [any PersistentModel.Type] = [
        DailyRecord.self,
        ActivityRecord.self,
        RaceRecord.self,
        SyncState.self,
    ]

    public static func container(inMemory: Bool) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}
