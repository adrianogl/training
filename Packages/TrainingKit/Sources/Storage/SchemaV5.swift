import Foundation
import SwiftData

public enum SchemaV5: VersionedSchema {
    public static let versionIdentifier = Schema.Version(5, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV5.DailyRecord.self,
            SchemaV5.ActivityRecord.self,
            SchemaV5.RaceRecord.self,
            SchemaV5.SyncState.self,
            SchemaV5.HeartRateZonesRecord.self,
            SchemaV5.ThresholdHistoryRecord.self,
            SchemaV5.RaceDecisionRecord.self,
        ]
    }
}
