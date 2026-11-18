import Foundation
import SwiftData

public enum SchemaV9: VersionedSchema {
    public static let versionIdentifier = Schema.Version(9, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV9.DailyRecord.self,
            SchemaV9.ActivityRecord.self,
            SchemaV9.RaceRecord.self,
            SchemaV9.SyncState.self,
            SchemaV9.HeartRateZonesRecord.self,
            SchemaV9.ThresholdHistoryRecord.self,
            SchemaV9.RaceDecisionRecord.self,
            SchemaV9.GoalRecord.self,
        ]
    }
}
