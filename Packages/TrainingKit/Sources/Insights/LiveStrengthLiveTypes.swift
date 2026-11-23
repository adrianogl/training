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
