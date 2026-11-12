import Foundation
import SwiftData

public enum SchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV4.DailyRecord.self,
            SchemaV4.ActivityRecord.self,
            SchemaV4.RaceRecord.self,
            SchemaV4.SyncState.self,
            SchemaV4.HeartRateZonesRecord.self,
            SchemaV4.ThresholdHistoryRecord.self,
            SchemaV4.RaceDecisionRecord.self,
        ]
    }
}
