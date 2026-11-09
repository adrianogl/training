import Metrics
import Reports
import Storage
import TrainingCore

public struct ReadinessSupport: Sendable, Equatable {
    public var hrvVsBaseline: Double?
    public var sleepScore: Int?
    public var acuteChronic: Double?
    public var stress: Int?

    public init(hrvVsBaseline: Double?, sleepScore: Int?, acuteChronic: Double?, stress: Int?) {
        self.hrvVsBaseline = hrvVsBaseline
        self.sleepScore = sleepScore
        self.acuteChronic = acuteChronic
        self.stress = stress
    }
}

public struct WeekVolume: Sendable, Equatable {
    public var perDay: [Day: Double]
    public var total: Double
    public var lastWeek: Double
    public var average4Weeks: Double

    public init(perDay: [Day: Double], total: Double, lastWeek: Double, average4Weeks: Double) {
        self.perDay = perDay
        self.total = total
        self.lastWeek = lastWeek
        self.average4Weeks = average4Weeks
    }
}

public struct TodaySummary: Sendable {
    public var readiness: ReadinessBreakdown?
    public var verdict: ReadinessVerdict?
    public var supporting: ReadinessSupport
    public var fitness: FitnessOutlook
    public var race: RaceOutlook
    public var raceCountdownDays: Int?
    public var racePriority: RacePriority?
    public var week: WeekVolume
    public var predictions: [Prediction]
    public var lastRunId: Int64?

    public init(
        readiness: ReadinessBreakdown?,
        verdict: ReadinessVerdict?,
        supporting: ReadinessSupport,
        fitness: FitnessOutlook,
        race: RaceOutlook,
        raceCountdownDays: Int?,
        racePriority: RacePriority?,
        week: WeekVolume,
        predictions: [Prediction],
        lastRunId: Int64?
    ) {
        self.readiness = readiness
        self.verdict = verdict
        self.supporting = supporting
        self.fitness = fitness
        self.race = race
        self.raceCountdownDays = raceCountdownDays
        self.racePriority = racePriority
        self.week = week
        self.predictions = predictions
        self.lastRunId = lastRunId
    }
}
