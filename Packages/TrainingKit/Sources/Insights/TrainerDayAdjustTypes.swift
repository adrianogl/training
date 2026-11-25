import Foundation
import TrainingCore

public enum DayAdjustOrigin: String, Codable, Sendable {
    case usual, now
}

public struct DayAdjustEntries: Codable, Sendable, Equatable {
    public var day: Day
    public var hour: Int
    public var origin: DayAdjustOrigin
    public var score: Int?
    public var temperature: Double?
    public var dewPoint: Double?
    public var radiation: Double?
    public var hotSessions: Int
    public var heavyLegs: Bool
    public var computedAt: Date

    public init(
        day: Day, hour: Int, origin: DayAdjustOrigin, score: Int?, temperature: Double?, dewPoint: Double?, radiation: Double?,
        hotSessions: Int, heavyLegs: Bool, computedAt: Date
    ) {
        self.day = day
        self.hour = hour
        self.origin = origin
        self.score = score
        self.temperature = temperature
        self.dewPoint = dewPoint
        self.radiation = radiation
        self.hotSessions = hotSessions
        self.heavyLegs = heavyLegs
        self.computedAt = computedAt
    }
}

public struct TrainerPaceRange: Codable, Sendable, Equatable {
    public var low: Double
    public var high: Double

    public init(low: Double, high: Double) {
        self.low = low
        self.high = high
    }
}

public struct TrainerDayAdjustment: Sendable, Equatable {
    public var workout: TrainerWorkout
    public var original: [TrainerPaceRange]
    public var originalPace: TrainerPaceRange?
    public var seconds: Int
    public var reasons: [DayAdjustReason]
    public var shortened: Bool
}

public enum TrainerDayAdjustResult: Sendable, Equatable {
    case none
    case adjusted(TrainerDayAdjustment)
    case swap(reasons: [DayAdjustReason])
    case rest
}
