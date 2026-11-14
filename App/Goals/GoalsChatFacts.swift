import Foundation
import Insights
import TrainingCore
import WorkoutAnalysis

enum GoalsChatFacts {
    private typealias C = GoalsChatConstants

    static func lines(_ snapshots: [GoalSnapshot]) -> [String] {
        snapshots.map { snapshot in
            switch snapshot.progress {
            case .time(let progress): timeLine(snapshot, progress)
            case .continuousLong(let progress): longLine(snapshot, progress)
            }
        }
    }

    static func terminated(_ text: String) -> String {
        text.hasSuffix(".") ? text : text + "."
    }

    static func shortDay(_ day: Day) -> String {
        day.chartDate.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale))
    }

    private static func timeLine(_ snapshot: GoalSnapshot, _ progress: TimeGoalProgress) -> String {
        var text = C.prefix + GoalsText.title(kind: snapshot.kind, distanceKm: snapshot.distanceKm, targetSeconds: snapshot.targetSeconds)
        if let today = progress.todaySeconds { text += String(format: C.timeTodayFormat, WorkoutFormat.clock(today)) }
        if let gap = progress.gapSeconds { text += gap > 0 ? String(format: C.timeRemainingFormat, WorkoutFormat.clock(gap)) : C.timeAhead }
        if let day = progress.achievedOn { text += String(format: C.achievedFormat, shortDay(day)) }
        if let deadline = snapshot.deadline { text += String(format: C.deadlineFormat, shortDay(deadline)) }
        return terminated(text)
    }

    private static func longLine(_ snapshot: GoalSnapshot, _ progress: LongGoalProgress) -> String {
        var text = C.prefix + String(format: C.longFormat, GoalsText.kilometers(snapshot.distanceKm), WorkoutFormat.clock(snapshot.paceSecondsPerKm ?? 0))
        text += progress.runs.isEmpty ? C.longEmpty : String(format: C.longRunsFormat, progress.metCount, progress.runs.count)
        if let best = progress.bestContinuousKm { text += String(format: C.longBestFormat, TodayText.decimal(best, fractionDigits: 1)) }
        if let day = progress.achievedOn { text += String(format: C.longAchievedFormat, shortDay(day)) }
        return terminated(text)
    }
}
