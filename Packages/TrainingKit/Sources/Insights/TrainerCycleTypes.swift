import Foundation
import TrainingCore

public enum TrainerCycleVerdict: String, Codable, Sendable {
    case increase, keep, decrease
}

public struct TrainerCycleWeek: Sendable, Equatable {
    public var index: Int
    public var start: Day
    public var doneMeters: Double
    public var plannedMeters: Double

    public init(index: Int, start: Day, doneMeters: Double, plannedMeters: Double) {
        self.index = index
        self.start = start
        self.doneMeters = doneMeters
        self.plannedMeters = plannedMeters
    }
}

public struct TrainerCycleCount: Sendable, Equatable {
    public var done: Int
    public var total: Int

    public init(done: Int, total: Int) {
        self.done = done
        self.total = total
    }
}

public struct TrainerCycleChange: Sendable, Equatable {
    public var meters: Double
    public var first: Double
    public var last: Double

    public init(meters: Double, first: Double, last: Double) {
        self.meters = meters
        self.first = first
        self.last = last
    }
}

public enum TrainerCycleReason: Sendable, Equatable {
    case volume(share: Double, weeksBelow: Int)
    case readiness(first: Double, last: Double)
    case lightWeeks(Int)
    case prediction(TrainerCycleChange)
    case race(seconds: Double, goal: Double)
    case tooShort(weeks: Int)
    case noProgress
}

public struct TrainerCycleReview: Sendable, Equatable {
    public var first: Day
    public var last: Day
    public var endedEarly: Bool
    public var weeks: [TrainerCycleWeek]
    public var long: TrainerCycleCount
    public var threshold: TrainerCycleCount
    public var vo2: TrainerCycleCount
    public var mediumLong: TrainerCycleCount
    public var longestLongMeters: Double?
    public var longestLongPlannedMeters: Double?
    public var readinessFirst: Double?
    public var readinessLast: Double?
    public var lowReadinessDays: Int
    public var extraLightWeeks: [Day]
    public var longsMissed: Int
    public var predictions: [TrainerCycleChange]
    public var raceSeconds: Double?
    public var goalSeconds: Double?
    public var verdict: TrainerCycleVerdict
    public var reasons: [TrainerCycleReason]
    public var currentStartMeters: Double
    public var currentPeakMeters: Double
    public var suggestedStartMeters: Double
    public var suggestedPeakMeters: Double

    public var doneMeters: Double { weeks.reduce(0) { $0 + $1.doneMeters } }
    public var plannedMeters: Double { weeks.reduce(0) { $0 + $1.plannedMeters } }
    public var doneShare: Double { plannedMeters == 0 ? 0 : doneMeters / plannedMeters }

    public init(
        first: Day, last: Day, endedEarly: Bool, weeks: [TrainerCycleWeek],
        long: TrainerCycleCount, threshold: TrainerCycleCount, vo2: TrainerCycleCount, mediumLong: TrainerCycleCount,
        longestLongMeters: Double?, longestLongPlannedMeters: Double?,
        readinessFirst: Double?, readinessLast: Double?, lowReadinessDays: Int,
        extraLightWeeks: [Day], longsMissed: Int, predictions: [TrainerCycleChange],
        raceSeconds: Double?, goalSeconds: Double?,
        verdict: TrainerCycleVerdict, reasons: [TrainerCycleReason],
        currentStartMeters: Double, currentPeakMeters: Double, suggestedStartMeters: Double, suggestedPeakMeters: Double
    ) {
        self.first = first
        self.last = last
        self.endedEarly = endedEarly
        self.weeks = weeks
        self.long = long
        self.threshold = threshold
        self.vo2 = vo2
        self.mediumLong = mediumLong
        self.longestLongMeters = longestLongMeters
        self.longestLongPlannedMeters = longestLongPlannedMeters
        self.readinessFirst = readinessFirst
        self.readinessLast = readinessLast
        self.lowReadinessDays = lowReadinessDays
        self.extraLightWeeks = extraLightWeeks
        self.longsMissed = longsMissed
        self.predictions = predictions
        self.raceSeconds = raceSeconds
        self.goalSeconds = goalSeconds
        self.verdict = verdict
        self.reasons = reasons
        self.currentStartMeters = currentStartMeters
        self.currentPeakMeters = currentPeakMeters
        self.suggestedStartMeters = suggestedStartMeters
        self.suggestedPeakMeters = suggestedPeakMeters
    }
}
