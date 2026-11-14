import Foundation
import SwiftData

public enum SchemaV6: VersionedSchema {
    public static let versionIdentifier = Schema.Version(6, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV6.DailyRecord.self,
            SchemaV6.ActivityRecord.self,
            SchemaV6.RaceRecord.self,
            SchemaV6.SyncState.self,
            SchemaV6.HeartRateZonesRecord.self,
            SchemaV6.ThresholdHistoryRecord.self,
            SchemaV6.RaceDecisionRecord.self,
        ]
    }
}
