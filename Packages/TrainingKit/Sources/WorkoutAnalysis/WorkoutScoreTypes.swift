public enum ScorePart: String, Sendable, Codable {
    case execution, intent, cost
}

public enum ScoreReason: String, Sendable, Codable {
    case blocksOffTarget, incompleteStep, notExecuted, easyTooHard, hardTooEasy, heartRateTargetMissed
    case lessEfficient, moreEfficient, noHeartRate, noZones, noHistory, noPrescription
}

public struct ScoreItem: Sendable, Equatable, Codable {
    public var part: ScorePart
    public var points: Double
    public var maximum: Double
    public var reason: ScoreReason?

    public init(part: ScorePart, points: Double, maximum: Double, reason: ScoreReason?) {
        self.part = part
        self.points = points
        self.maximum = maximum
        self.reason = reason
    }
}

public struct WorkoutScore: Sendable, Equatable, Codable {
    public var value: Int
    public var items: [ScoreItem]

    public init(value: Int, items: [ScoreItem]) {
        self.value = value
        self.items = items
    }
}
