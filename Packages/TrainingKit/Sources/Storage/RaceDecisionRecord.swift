import Foundation
import SwiftData

@Model
public final class RaceDecisionRecord {
    public var activityId: Int64 = 0
    public var decision: String = ""
    public var decidedAt: Date = Date.now

    public var raceDecision: RaceDecision? {
        get { RaceDecision(rawValue: decision) }
        set { decision = newValue?.rawValue ?? "" }
    }

    public init(activityId: Int64, decision: RaceDecision, decidedAt: Date = .now) {
        self.activityId = activityId
        self.decision = decision.rawValue
        self.decidedAt = decidedAt
    }
}
