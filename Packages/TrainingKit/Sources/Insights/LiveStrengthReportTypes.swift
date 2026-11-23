import Foundation

public enum LiveStrengthChange: Sendable, Equatable {
    case asPlanned
    case heavier(Double)
    case lighter(Double)
    case fewerReps(Int)
    case skipped
}

public struct LiveStrengthExerciseSummary: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var sets: [LiveStrengthSetResult]
    public var change: LiveStrengthChange
}

public struct LiveStrengthSummary: Sendable, Equatable {
    public var volume: Double
    public var previousVolume: Double?
    public var volumeChange: Double?
    public var durationSeconds: Double
    public var averageHeartRate: Int?
    public var setsDone: Int
    public var setsPlanned: Int
    public var offPlan: Int
    public var exercises: [LiveStrengthExerciseSummary]
    public var skipped: [String]
    public var loads: [String: StrengthLoadRecord]
}
