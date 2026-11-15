import Foundation
import Insights
import Storage
import TrainingCore
import WorkoutAnalysis

enum GoalsText {
    private typealias C = GoalsConstants

    static func distanceLabel(_ km: Double) -> String {
        C.distances.first { abs($0.km - km) < 0.01 }?.label ?? "\(TodayText.decimal(km, fractionDigits: 1)) km"
    }

    static func kilometers(_ km: Double) -> String {
        TodayText.decimal(km, fractionDigits: abs(km - km.rounded()) < 0.05 ? 0 : 1)
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

    static func status(_ snapshot: GoalSnapshot) -> GoalStatus? {
        switch snapshot.progress {
        case .time(let progress):
            if let day = progress.achievedOn { return GoalStatus(text: String(format: C.achievedFormat, GoalsChatFacts.shortDay(day)), good: true) }
            guard let gap = progress.gapSeconds else { return nil }
            return gap <= 0 ? GoalStatus(text: C.ahead, good: true) : GoalStatus(text: String(format: C.remainingFormat, WorkoutFormat.clock(gap)), good: false)
        case .continuousLong(let progress):
            guard !progress.runs.isEmpty else { return nil }
            if let day = progress.achievedOn { return GoalStatus(text: String(format: C.achievedFormat, GoalsChatFacts.shortDay(day)), good: true) }
            return GoalStatus(text: String(format: C.runsFormat, progress.metCount, progress.runs.count), good: progress.metCount > 0)
        }
    }

    static func title(_ snapshot: GoalSnapshot) -> String {
        title(kind: snapshot.kind, distanceKm: snapshot.distanceKm, targetSeconds: snapshot.targetSeconds)
    }

    static func title(_ goal: GoalRecord) -> String {
        title(kind: goal.goalKind ?? .time, distanceKm: goal.distanceKm, targetSeconds: goal.targetSeconds)
    }

    static func line(_ goal: GoalRecord) -> String {
        line(kind: goal.goalKind ?? .time, distanceKm: goal.distanceKm, targetSeconds: goal.targetSeconds, paceSecondsPerKm: goal.paceSecondsPerKm, deadline: goal.deadline)
    }
}
