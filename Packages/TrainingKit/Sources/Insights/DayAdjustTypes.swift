import Foundation
import GarminAPI

public enum DayAdjustShape: Sendable, Equatable {
    case continuous, intervals, long
}

public struct DayAdjustInput: Sendable {
    public var plan: PlannedWorkout
    public var shape: DayAdjustShape
    public var score: Int?
    public var temperature: Double?
    public var dewPoint: Double?
    public var radiation: Double?
    public var hotSessions: Int
    public var heavyLegs: Bool

    public init(
        plan: PlannedWorkout, shape: DayAdjustShape, score: Int?, temperature: Double?, dewPoint: Double?,
        hotSessions: Int, heavyLegs: Bool, radiation: Double? = nil
    ) {
        self.radiation = radiation
        self.plan = plan
        self.shape = shape
        self.score = score
        self.temperature = temperature
        self.dewPoint = dewPoint
        self.hotSessions = hotSessions
        self.heavyLegs = heavyLegs
    }
}

public enum DayAdjustReason: Sendable, Equatable {
    case readiness(score: Int, seconds: Int)
    case heat(temperature: Double, dewPoint: Double, seconds: Int)
    case heavyLegs(seconds: Int)
    case noForecast
}

public enum DayAdjustResult: Sendable, Equatable {
    case none
    case adjusted(steps: [PlannedStep], original: [PlannedStep], seconds: Int, reasons: [DayAdjustReason], shortened: Bool)
    case swap(reasons: [DayAdjustReason])
    case rest
}

public struct DayAdjustFactors: Sendable, Equatable {
    public var score: Int?
    public var readinessSeconds: Int
    public var shorten: Bool
    public var temperature: Double?
    public var dewPoint: Double?
    public var heatShare: Double?
    public var legsSeconds: Int

    public var fixedSeconds: Int { readinessSeconds + legsSeconds }
}

public enum DayAdjustDecision: Sendable, Equatable {
    case apply(seconds: Int, reasons: [DayAdjustReason])
    case swap(reasons: [DayAdjustReason])
}
