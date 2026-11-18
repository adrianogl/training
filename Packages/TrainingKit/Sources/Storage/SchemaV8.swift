import Foundation
import SwiftData

public enum SchemaV8: VersionedSchema {
    public static let versionIdentifier = Schema.Version(8, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV8.DailyRecord.self,
            SchemaV8.ActivityRecord.self,
            SchemaV8.RaceRecord.self,
            SchemaV8.SyncState.self,
            SchemaV8.HeartRateZonesRecord.self,
            SchemaV8.ThresholdHistoryRecord.self,
            SchemaV8.RaceDecisionRecord.self,
            SchemaV8.GoalRecord.self,
        ]
    }
}
