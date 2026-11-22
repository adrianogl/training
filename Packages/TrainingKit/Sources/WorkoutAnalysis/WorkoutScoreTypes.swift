public enum ScorePart: String, Sendable, Codable {
    case execution, intent, cost
}

public enum ScoreReason: String, Sendable, Codable {
    case blocksOffTarget, incompleteStep, notExecuted, easyTooHard, hardTooEasy, heartRateTargetMissed
    case lessEfficient, moreEfficient, noHeartRate, noZones, noHistory, noPrescription
    case slowerThanTarget, offStrategy, noRaceTarget, noSplits, noPreviousRace, lessEfficientThanRaces, moreEfficientThanRaces
}

public struct RaceScoreInput: Sendable, Equatable {
    public var raceDistance: Double
    public var targetSeconds: Double?
    public var distance: Double?
    public var seconds: Double?
    public var referencePaces: [Int: Double]

    public init(raceDistance: Double, targetSeconds: Double?, distance: Double?, seconds: Double?, referencePaces: [Int: Double] = [:]) {
        self.raceDistance = raceDistance
        self.targetSeconds = targetSeconds
        self.distance = distance
        self.seconds = seconds
        self.referencePaces = referencePaces
    }

    public var targetPace: Double? {
        guard let targetSeconds, targetSeconds > 0, raceDistance > 0 else { return nil }
        return targetSeconds / (raceDistance / AnalysisConstants.metersPerKilometer)
    }
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
