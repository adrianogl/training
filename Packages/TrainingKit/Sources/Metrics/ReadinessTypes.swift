public struct HRVBaseline: Codable, Sendable, Equatable {
    public var lowUpper: Double
    public var balancedLow: Double
    public var balancedUpper: Double

    public init(lowUpper: Double, balancedLow: Double, balancedUpper: Double) {
        self.lowUpper = lowUpper
        self.balancedLow = balancedLow
        self.balancedUpper = balancedUpper
    }
}

public struct ReadinessInput: Sendable {
    public var hrvLastNight: Double?
    public var hrvBaseline: HRVBaseline?
    public var sleepScore: Double?
    public var bodyBatteryMorningMax: Double?
    public var acuteChronic: Double?

    public init(hrvLastNight: Double?, hrvBaseline: HRVBaseline?, sleepScore: Double?, bodyBatteryMorningMax: Double?, acuteChronic: Double?) {
        self.hrvLastNight = hrvLastNight
        self.hrvBaseline = hrvBaseline
        self.sleepScore = sleepScore
        self.bodyBatteryMorningMax = bodyBatteryMorningMax
        self.acuteChronic = acuteChronic
    }
}

public enum ReadinessVerdict: String, Sendable {
    case rest, moderate, hard
}

public struct Readiness: Sendable, Equatable {
    public var score: Int
    public var partial: Bool
    public var verdict: ReadinessVerdict

    public init(score: Int, partial: Bool, verdict: ReadinessVerdict) {
        self.score = score
        self.partial = partial
        self.verdict = verdict
    }
}
