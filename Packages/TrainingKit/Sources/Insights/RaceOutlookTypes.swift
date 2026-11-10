import Metrics
import Projections
import TrainingCore

public enum GoalCrossing: Sendable, Equatable {
    case on(Day)
    case alreadyBeaten
    case unreachable
    case noGoal
}

public struct RaceOutlook: Sendable {
    public var distance: Double
    public var label: String
    public var today: Double?
    public var raceDay: ProjectionPoint?
    public var yearAgo: Double?
    public var series: [(Day, Double)]
    public var projection: [ProjectionPoint]
    public var longProjection: [ProjectionPoint]
    public var goalSeconds: Double?
    public var goalCrossing: GoalCrossing
    public var assessment: GoalAssessment?

    public init(
        distance: Double,
        label: String,
        today: Double?,
        raceDay: ProjectionPoint?,
        yearAgo: Double?,
        series: [(Day, Double)],
        projection: [ProjectionPoint],
        longProjection: [ProjectionPoint] = [],
        goalSeconds: Double?,
        goalCrossing: GoalCrossing,
        assessment: GoalAssessment?
    ) {
        self.distance = distance
        self.label = label
        self.today = today
        self.raceDay = raceDay
        self.yearAgo = yearAgo
        self.series = series
        self.projection = projection
        self.longProjection = longProjection
        self.goalSeconds = goalSeconds
        self.goalCrossing = goalCrossing
        self.assessment = assessment
    }
}

public enum StrategyTargetSource: Sendable, Hashable {
    case raceDayProjection
    case todayPrediction
    case goal
    case frozen
}

public struct StrategyTarget: Sendable, Equatable {
    public var seconds: Double
    public var source: StrategyTargetSource
    public var frozenOn: Day?

    public init(seconds: Double, source: StrategyTargetSource, frozenOn: Day?) {
        self.seconds = seconds
        self.source = source
        self.frozenOn = frozenOn
    }
}
