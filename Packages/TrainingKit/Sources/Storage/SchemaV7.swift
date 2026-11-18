import Foundation
import SwiftData

public enum SchemaV7: VersionedSchema {
    public static let versionIdentifier = Schema.Version(7, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV7.DailyRecord.self,
            SchemaV7.ActivityRecord.self,
            SchemaV7.RaceRecord.self,
            SchemaV7.SyncState.self,
            SchemaV7.HeartRateZonesRecord.self,
            SchemaV7.ThresholdHistoryRecord.self,
            SchemaV7.RaceDecisionRecord.self,
            SchemaV7.GoalRecord.self,
        ]
    }
}
