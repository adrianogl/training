import FITReader
import Foundation
import Insights
import Storage
import WorkoutAnalysis

enum WorkoutNoticeGoals {
    private typealias C = WorkoutNoticeConstants

    static func evaluate(record: ActivityRecord, goals: [GoalSnapshot]) -> WorkoutGoalNotice? {
        guard !goals.isEmpty else { return nil }
        let continuity = goals.contains { $0.kind == .continuousLong } ? self.continuity(record) : nil
        var note: String?
        for goal in goals {
            switch goal.kind {
            case .continuousLong:
                guard let continuity else { continue }
                if continuity.meetsContinuousGoal(distanceKm: goal.distanceKm, paceSecondsPerKm: goal.paceSecondsPerKm ?? 0) {
                    return WorkoutGoalNotice(metGoal: title(goal))
                }
                if note == nil { note = nearMiss(continuity, goal: goal) }
            case .time:
                if meetsTime(record, goal: goal) { return WorkoutGoalNotice(metGoal: title(goal)) }
            }
        }
        return note.map { WorkoutGoalNotice(note: $0) }
    }

    private static func continuity(_ record: ActivityRecord) -> RunContinuity? {
        let samples = record.samplesData.flatMap { try? JSONDecoder().decode([FITSample].self, from: $0) } ?? []
        return runContinuity(samples)
    }

    private static func title(_ goal: GoalSnapshot) -> String {
        switch goal.kind {
        case .time: GoalsText.title(kind: goal.kind, distanceKm: goal.distanceKm, targetSeconds: goal.targetSeconds)
        case .continuousLong: String(format: GoalsConstants.longTitleFormat, GoalsText.kilometers(goal.distanceKm))
        }
    }

    private static func meetsTime(_ record: ActivityRecord, goal: GoalSnapshot) -> Bool {
        guard let target = goal.targetSeconds, let distance = record.distance, let seconds = record.duration else { return false }
        let meters = goal.distanceKm * WorkoutConstants.metersPerKilometer
        guard distance >= meters * C.timeMatchLow, distance <= meters * C.timeMatchHigh else { return false }
        return seconds * (meters / distance) <= target
    }

    private static func nearMiss(_ continuity: RunContinuity, goal: GoalSnapshot) -> String? {
        let meters = goal.distanceKm * WorkoutConstants.metersPerKilometer
        guard continuity.totalMeters >= meters * C.longNearShare, !continuity.pauses.isEmpty else { return nil }
        let pauses = continuity.pauses.count == 1 ? C.pauseOne : String(format: C.pausesFormat, continuity.pauses.count)
        return String(
            format: C.pauseNoteFormat,
            pauses,
            TodayText.decimal(continuity.longestContinuousMeters / WorkoutConstants.metersPerKilometer, fractionDigits: 1),
            GoalsText.kilometers(goal.distanceKm)
        )
    }
}
