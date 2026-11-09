import Metrics

public enum OverallVerdict: String, Sendable {
    case better, stable, worse
}

public struct OverallFacts: Sendable, Equatable {
    public var verdict: OverallVerdict
    public var improved: Int
    public var worsened: Int
    public var total: Int
    public var goalGapSeconds: Double?
    public var raceDayGapSeconds: Double?

    public init(
        verdict: OverallVerdict, improved: Int, worsened: Int, total: Int,
        goalGapSeconds: Double?, raceDayGapSeconds: Double?
    ) {
        self.verdict = verdict
        self.improved = improved
        self.worsened = worsened
        self.total = total
        self.goalGapSeconds = goalGapSeconds
        self.raceDayGapSeconds = raceDayGapSeconds
    }
}

public protocol InsightNarrator: Sendable {
    func readinessSentence(_ breakdown: ReadinessBreakdown, verdict: ReadinessVerdict) async -> String
    func overallSentence(_ facts: OverallFacts) async -> String
}

protocol InsightGenerator: Sendable {
    func generate(instructions: String, prompt: String) async throws -> String
}
