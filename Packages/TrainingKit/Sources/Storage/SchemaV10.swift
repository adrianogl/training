import Foundation
import SwiftData

public enum SchemaV10: VersionedSchema {
    public static let versionIdentifier = Schema.Version(10, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV10.DailyRecord.self,
            SchemaV10.ActivityRecord.self,
            SchemaV10.RaceRecord.self,
            SchemaV10.SyncState.self,
            SchemaV10.HeartRateZonesRecord.self,
            SchemaV10.ThresholdHistoryRecord.self,
            SchemaV10.RaceDecisionRecord.self,
            SchemaV10.GoalRecord.self,
        ]
    }
}
