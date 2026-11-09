import Foundation
import SwiftData

public enum SchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV2.DailyRecord.self,
            SchemaV2.ActivityRecord.self,
            SchemaV2.RaceRecord.self,
            SchemaV2.SyncState.self,
            SchemaV2.HeartRateZonesRecord.self,
        ]
    }
}
