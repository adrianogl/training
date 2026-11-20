import Foundation

enum StrengthPlanStoreConstants {
    static let fileName = "strength-plan.json"
    static let blobId = "strengthPlan"
    static let syncedStampKey = "strengthPlanSynced"
    static let documentStampKey = "strengthPlanDocument"
    static let migratedStamp = Date(timeIntervalSince1970: Date.distantPast.timeIntervalSince1970 + 0.001)
}
