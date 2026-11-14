import Foundation
import Storage
import TrainingCore
import WorkoutAnalysis

enum GoalsText {
    private typealias C = GoalsConstants

    static func distanceLabel(_ km: Double) -> String {
        C.distances.first { abs($0.km - km) < 0.01 }?.label ?? "\(TodayText.decimal(km, fractionDigits: 1)) km"
    }

    static func title(kind: GoalKind, distanceKm: Double, targetSeconds: Double?) -> String {
        switch kind {
        case .time: String(format: C.timeTitleFormat, distanceLabel(distanceKm), WorkoutFormat.clock(targetSeconds ?? 0))
        case .continuousLong: String(format: C.longTitleFormat, TodayText.decimal(distanceKm, fractionDigits: 1))
        }
    }

    static func line(kind: GoalKind, distanceKm: Double, targetSeconds: Double?, paceSecondsPerKm: Double?, deadline: String?) -> String {
        switch kind {
        case .time:
            let pace = String(format: C.timeLineFormat, WorkoutFormat.clock((targetSeconds ?? 0) / distanceKm))
            guard let deadline, let day = Day(iso: deadline) else { return pace }
            return pace + String(format: C.deadlineFormat, day.chartDate.formatted(.dateTime.day().month(.abbreviated).year().locale(WorkoutConstants.locale)))
        case .continuousLong:
            return String(format: C.longLineFormat, TodayText.decimal(distanceKm, fractionDigits: 1), WorkoutFormat.clock(paceSecondsPerKm ?? 0))
        }
    }

    static func title(_ goal: GoalRecord) -> String {
        title(kind: goal.goalKind ?? .time, distanceKm: goal.distanceKm, targetSeconds: goal.targetSeconds)
    }

    static func line(_ goal: GoalRecord) -> String {
        line(kind: goal.goalKind ?? .time, distanceKm: goal.distanceKm, targetSeconds: goal.targetSeconds, paceSecondsPerKm: goal.paceSecondsPerKm, deadline: goal.deadline)
    }
}
