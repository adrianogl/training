import Narrative

public enum IndicatorKind: String, CaseIterable, Sendable {
    case racePrediction, vo2max, fitness, zone2Pace, thresholdPace, monthlyVolume
}

public enum IndicatorTrend: String, Sendable {
    case better, same, worse, unknown
}

public struct Indicator: Sendable, Equatable {
    public var kind: IndicatorKind
    public var today: Double?
    public var delta: Double?
    public var goalGap: Double?
    public var trend: IndicatorTrend

    public init(kind: IndicatorKind, today: Double?, delta: Double?, goalGap: Double?, trend: IndicatorTrend) {
        self.kind = kind
        self.today = today
        self.delta = delta
        self.goalGap = goalGap
        self.trend = trend
    }
}

public struct OverallState: Sendable, Equatable {
    public var indicators: [Indicator]
    public var facts: OverallFacts

    public init(indicators: [Indicator], facts: OverallFacts) {
        self.indicators = indicators
        self.facts = facts
    }
}

struct IndicatorMargin {
    var value: Double
    var relative: Bool
}
