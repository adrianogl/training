import Foundation
import SwiftData

public enum SchemaV6: VersionedSchema {
    public static let versionIdentifier = Schema.Version(6, 0, 0)

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
