import Foundation
import Insights
import Reports
import TrainingCore
import WorkoutAnalysis

enum TodayOutlookText {
    private typealias C = TodayConstants
    private typealias G = GoalsConstants

    static func predictions(_ predictions: [Prediction]) -> [Prediction] {
        C.outlookPredictionLabels.compactMap { label in predictions.first { $0.label == label && $0.seconds != nil } }
    }

    static func goalStatus(_ snapshot: GoalSnapshot) -> TodayGoalStatus? {
        switch snapshot.progress {
        case .time(let progress):
            if let day = progress.achievedOn { return TodayGoalStatus(text: String(format: G.achievedFormat, shortDay(day)), good: true) }
            guard let gap = progress.gapSeconds else { return nil }
            return gap <= 0
                ? TodayGoalStatus(text: G.ahead, good: true)
                : TodayGoalStatus(text: String(format: G.remainingFormat, WorkoutFormat.clock(gap)), good: false)
        case .continuousLong(let progress):
            if let day = progress.achievedOn { return TodayGoalStatus(text: String(format: G.achievedFormat, shortDay(day)), good: true) }
            guard !progress.runs.isEmpty else { return nil }
            return TodayGoalStatus(text: String(format: C.outlookLongRunsFormat, progress.metCount, progress.runs.count), good: progress.metCount > 0)
        }
    }

    static func goalToday(_ snapshot: GoalSnapshot) -> String? {
        guard case .time(let progress) = snapshot.progress, let today = progress.todaySeconds else { return nil }
        return String(format: C.outlookGoalTodayFormat, WorkoutFormat.clock(today))
    }

    private static func shortDay(_ day: Day) -> String {
        day.chartDate.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale))
    }
}
