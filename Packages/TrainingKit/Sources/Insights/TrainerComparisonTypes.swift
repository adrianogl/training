import Foundation
import TrainingCore

public struct TrainerExternalWorkout: Sendable, Equatable {
    public var day: Day
    public var name: String
    public var totalMeters: Double
    public var steps: [TrainerStep]

    public init(day: Day, name: String, totalMeters: Double, steps: [TrainerStep]) {
        self.day = day
        self.name = name
        self.totalMeters = totalMeters
        self.steps = steps
    }
}

public enum TrainerComparisonMatch: String, Sendable, Equatable {
    case same
    case similar
    case different
}

public enum TrainerComparisonCloser: String, Sendable, Equatable {
    case external
    case beta
    case tie
}

public struct TrainerComparisonDay: Sendable, Equatable, Identifiable {
    public var day: Day
    public var beta: TrainerWorkout?
    public var external: TrainerExternalWorkout?
    public var externalKind: TrainerDayKind?
    public var externalSummary: String?
    public var betaSummary: String?
    public var match: TrainerComparisonMatch
    public var run: TrainerRun?
    public var closer: TrainerComparisonCloser?

    public var id: String { day.iso }
}

public struct TrainerComparisonWeek: Sendable, Equatable {
    public var start: Day
    public var days: [TrainerComparisonDay]
    public var externalMeters: Double
    public var betaMeters: Double
    public var externalQuality: Int
    public var betaQuality: Int
    public var sameKindDays: Int
    public var comparedDays: Int
}

public struct TrainerScoreboard: Sendable, Equatable, Identifiable {
    public var weekIndex: Int
    public var start: Day
    public var doneMeters: Double
    public var plannedMeters: Double
    public var qualityOnTarget: Int
    public var qualityTotal: Int
    public var longClosed: Bool?
    public var longBlocks: Bool
    public var predictionDeltaSeconds: Double?
    public var predictionMeters: Double?

    public var id: Int { weekIndex }

    public init(
        weekIndex: Int, start: Day, doneMeters: Double, plannedMeters: Double, qualityOnTarget: Int, qualityTotal: Int,
        longClosed: Bool?, longBlocks: Bool, predictionDeltaSeconds: Double?, predictionMeters: Double?
    ) {
        self.weekIndex = weekIndex
        self.start = start
        self.doneMeters = doneMeters
        self.plannedMeters = plannedMeters
        self.qualityOnTarget = qualityOnTarget
        self.qualityTotal = qualityTotal
        self.longClosed = longClosed
        self.longBlocks = longBlocks
        self.predictionDeltaSeconds = predictionDeltaSeconds
        self.predictionMeters = predictionMeters
    }
}

public struct TrainerReadinessFactor: Sendable, Equatable {
    public var name: String
    public var value: Int

    public init(name: String, value: Int) {
        self.name = name
        self.value = value
    }
}

public struct TrainerReadinessSuggestion: Sendable, Equatable {
    public var day: Day
    public var score: Int
    public var factor: TrainerReadinessFactor?
    public var workoutTitle: String
    public var swapDay: Day?

    public var swaps: Bool { swapDay != nil }

    public init(day: Day, score: Int, factor: TrainerReadinessFactor?, workoutTitle: String, swapDay: Day?) {
        self.day = day
        self.score = score
        self.factor = factor
        self.workoutTitle = workoutTitle
        self.swapDay = swapDay
    }
}
