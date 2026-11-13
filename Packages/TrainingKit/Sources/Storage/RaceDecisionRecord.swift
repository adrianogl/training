import Foundation
import SwiftData

@Model
public final class RaceDecisionRecord {
    public var activityId: Int64 = 0
    public var decision: String = ""
    @Attribute(originalName: "decidedAt") public var updatedAt: Date = Date.now
    public var deletedAt: Date? = nil

    public var raceDecision: RaceDecision? {
        get { RaceDecision(rawValue: decision) }
        set { decision = newValue?.rawValue ?? "" }
    }

    public init(activityId: Int64, decision: RaceDecision, updatedAt: Date = .now, deletedAt: Date? = nil) {
        self.activityId = activityId
        self.decision = decision.rawValue
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
