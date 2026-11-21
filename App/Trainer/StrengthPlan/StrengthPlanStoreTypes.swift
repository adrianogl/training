import Foundation
import Insights

struct StrengthPlanDocument: Codable, Sendable, Equatable, Identifiable {
    var plan: StrengthPlan?
    var updatedAt: Date
    var migrated: Bool

    var id: String { StrengthPlanStoreConstants.blobId }

    static let empty = StrengthPlanDocument(plan: nil, updatedAt: .distantPast, migrated: false)
}
