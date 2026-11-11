import Foundation
import SwiftData

public enum SchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Storage.DailyRecord.self,
            Storage.ActivityRecord.self,
            Storage.RaceRecord.self,
            Storage.SyncState.self,
            Storage.HeartRateZonesRecord.self,
            Storage.ThresholdHistoryRecord.self,
            Storage.RaceDecisionRecord.self,
        ]
    }
}
