import Foundation

public enum LiveStrengthWatchPhase: String, Codable, Sendable, Equatable {
    case set, timed, rest, restOver, adjust, exerciseDone, pending, paused, finished
}

public struct LiveStrengthWatchStatus: Codable, Sendable, Equatable {
    public var phase: LiveStrengthWatchPhase
    public var heartRate: Int?
    public var restEndsAt: Date?

    public init(phase: LiveStrengthWatchPhase, heartRate: Int? = nil, restEndsAt: Date? = nil) {
        self.phase = phase
        self.heartRate = heartRate
        self.restEndsAt = restEndsAt
    }
}

public enum LiveStrengthMoment: String, Codable, Sendable, Equatable {
    case doing, resting, restOver, paused, finished
}

public struct LiveStrengthCard: Codable, Sendable, Equatable {
    public var title: String
    public var setsDone: Int
    public var setsTotal: Int
    public var heartRate: Int?
    public var moment: LiveStrengthMoment
    public var exerciseName: String?
    public var shortName: String?
    public var setNumber: Int
    public var setCount: Int
    public var exerciseSetsDone: Int
    public var target: String?
    public var last: String?
    public var lastDone: String?
    public var restEndsAt: Date?
    public var restSeconds: Int?
}

public enum LiveStrengthRowState: String, Sendable, Equatable {
    case done, next, pending
}

public struct LiveStrengthSetRow: Sendable, Equatable, Identifiable {
    public var id: Int { number }
    public var number: Int
    public var state: LiveStrengthRowState
    public var done: LiveStrengthSetResult?
    public var doneText: String?
    public var repsBelow: Bool
    public var weightChanged: Bool
    public var plan: String
    public var last: String?
}

public struct LiveStrengthNow: Sendable, Equatable {
    public var number: Int
    public var exercise: LiveStrengthExercise
    public var rounds: Int
    public var restSeconds: Int
    public var rows: [LiveStrengthSetRow]
}

public enum LiveStrengthItemState: String, Sendable, Equatable {
    case done, pending, skipped, leftOut
}

public struct LiveStrengthItem: Sendable, Equatable, Identifiable {
    public var id: String { exercise.id }
    public var number: Int
    public var exercise: LiveStrengthExercise
    public var rounds: Int
    public var setsDone: Int
    public var state: LiveStrengthItemState
}

public struct LiveStrengthScreen: Sendable, Equatable {
    public var now: LiveStrengthNow?
    public var items: [LiveStrengthItem]
}
