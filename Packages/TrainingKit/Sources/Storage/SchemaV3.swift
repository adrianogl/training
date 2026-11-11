import Foundation
import SwiftData

public enum SchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            SchemaV3.DailyRecord.self,
            SchemaV3.ActivityRecord.self,
            SchemaV3.RaceRecord.self,
            SchemaV3.SyncState.self,
            SchemaV3.HeartRateZonesRecord.self,
        ]
    }
}
