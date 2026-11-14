import Foundation
import Storage
import TrainingCore
import WorkoutAnalysis

public struct TimeGoalProgress: Sendable, Equatable {
    public var todaySeconds: Double?
    public var gapSeconds: Double?
    public var crossing: GoalCrossing
    public var achievedOn: Day?
}

public struct LongRunCheck: Sendable, Equatable {
    public var activityId: Int64
    public var day: Day
    public var distanceKm: Double
    public var longestContinuousKm: Double?
    public var pauses: [RunPause]?
    public var paceSecondsPerKm: Double?
    public var met: Bool?
}

public struct LongGoalProgress: Sendable, Equatable {
    public var runs: [LongRunCheck]
    public var metCount: Int
    public var bestContinuousKm: Double?
    public var achievedOn: Day?
}

public enum GoalProgress: Sendable, Equatable {
    case time(TimeGoalProgress)
    case continuousLong(LongGoalProgress)
}

public struct GoalSnapshot: Sendable, Equatable {
    public var id: UUID
    public var kind: GoalKind
    public var distanceKm: Double
    public var targetSeconds: Double?
    public var deadline: Day?
    public var paceSecondsPerKm: Double?
    public var progress: GoalProgress

    public var targetPaceSecondsPerKm: Double? {
        switch kind {
        case .time: targetSeconds.map { $0 / distanceKm }
        case .continuousLong: paceSecondsPerKm
        }
    }
}
