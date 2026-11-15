import Metrics
import Projections
import TrainingCore

public enum GoalCrossing: Sendable, Equatable, Codable {
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

public enum StrategyTargetSource: Sendable, Hashable, Codable {
    case raceDayProjection
    case todayPrediction
    case goal
    case frozen
}

public struct StrategyTarget: Sendable, Equatable, Codable {
    public var seconds: Double
    public var source: StrategyTargetSource
    public var frozenOn: Day?

    public init(seconds: Double, source: StrategyTargetSource, frozenOn: Day?) {
        self.seconds = seconds
        self.source = source
        self.frozenOn = frozenOn
    }
}

extension RaceOutlook: Codable {
    private enum CodingKeys: String, CodingKey {
        case distance, label, today, raceDay, yearAgo, series, projection, longProjection, goalSeconds, goalCrossing, assessment
    }

    private struct SeriesPoint: Codable {
        let day: Day
        let value: Double
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            distance: try container.decode(Double.self, forKey: .distance),
            label: try container.decode(String.self, forKey: .label),
            today: try container.decodeIfPresent(Double.self, forKey: .today),
            raceDay: try container.decodeIfPresent(ProjectionPoint.self, forKey: .raceDay),
            yearAgo: try container.decodeIfPresent(Double.self, forKey: .yearAgo),
            series: try container.decode([SeriesPoint].self, forKey: .series).map { ($0.day, $0.value) },
            projection: try container.decode([ProjectionPoint].self, forKey: .projection),
            longProjection: try container.decode([ProjectionPoint].self, forKey: .longProjection),
            goalSeconds: try container.decodeIfPresent(Double.self, forKey: .goalSeconds),
            goalCrossing: try container.decode(GoalCrossing.self, forKey: .goalCrossing),
            assessment: try container.decodeIfPresent(GoalAssessment.self, forKey: .assessment)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(distance, forKey: .distance)
        try container.encode(label, forKey: .label)
        try container.encode(today, forKey: .today)
        try container.encode(raceDay, forKey: .raceDay)
        try container.encode(yearAgo, forKey: .yearAgo)
        try container.encode(series.map { SeriesPoint(day: $0.0, value: $0.1) }, forKey: .series)
        try container.encode(projection, forKey: .projection)
        try container.encode(longProjection, forKey: .longProjection)
        try container.encode(goalSeconds, forKey: .goalSeconds)
        try container.encode(goalCrossing, forKey: .goalCrossing)
        try container.encode(assessment, forKey: .assessment)
    }
}
