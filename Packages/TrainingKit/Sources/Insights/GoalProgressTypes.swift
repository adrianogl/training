import Foundation
import Storage
import TrainingCore
import WorkoutAnalysis

public struct TimeGoalProgress: Sendable, Equatable {
    public var todaySeconds: Double?
    public var gapSeconds: Double?
    public var crossing: GoalCrossing
    public var achievedOn: Day?

    public init(todaySeconds: Double?, gapSeconds: Double?, crossing: GoalCrossing, achievedOn: Day?) {
        self.todaySeconds = todaySeconds
        self.gapSeconds = gapSeconds
        self.crossing = crossing
        self.achievedOn = achievedOn
    }
}

public struct LongRunCheck: Sendable, Equatable {
    public var activityId: Int64
    public var day: Day
    public var distanceKm: Double
    public var longestContinuousKm: Double?
    public var pauses: [RunPause]?
    public var paceSecondsPerKm: Double?
    public var met: Bool?

    public init(activityId: Int64, day: Day, distanceKm: Double, longestContinuousKm: Double?, pauses: [RunPause]?, paceSecondsPerKm: Double?, met: Bool?) {
        self.activityId = activityId
        self.day = day
        self.distanceKm = distanceKm
        self.longestContinuousKm = longestContinuousKm
        self.pauses = pauses
        self.paceSecondsPerKm = paceSecondsPerKm
        self.met = met
    }
}

public struct LongGoalProgress: Sendable, Equatable {
    public var runs: [LongRunCheck]
    public var metCount: Int
    public var bestContinuousKm: Double?
    public var achievedOn: Day?

    public init(runs: [LongRunCheck], metCount: Int, bestContinuousKm: Double?, achievedOn: Day?) {
        self.runs = runs
        self.metCount = metCount
        self.bestContinuousKm = bestContinuousKm
        self.achievedOn = achievedOn
    }
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

    public init(id: UUID, kind: GoalKind, distanceKm: Double, targetSeconds: Double?, deadline: Day?, paceSecondsPerKm: Double?, progress: GoalProgress) {
        self.id = id
        self.kind = kind
        self.distanceKm = distanceKm
        self.targetSeconds = targetSeconds
        self.deadline = deadline
        self.paceSecondsPerKm = paceSecondsPerKm
        self.progress = progress
    }

    public var targetPaceSecondsPerKm: Double? {
        switch kind {
        case .time: targetSeconds.map { $0 / distanceKm }
        case .continuousLong: paceSecondsPerKm
        }
    }
}
