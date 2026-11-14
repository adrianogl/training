import Foundation
import Storage
import TrainingCore
import WorkoutAnalysis

enum GoalDraftParser {
    private typealias C = GoalsConstants

    static func draft(_ goal: GoalRecord?) -> GoalDraft {
        guard let goal, let kind = goal.goalKind else { return GoalDraft() }
        var draft = GoalDraft(kind: kind)
        switch kind {
        case .time:
            draft.distanceKm = goal.distanceKm
            draft.time = goal.targetSeconds.map(WorkoutFormat.clock) ?? ""
            if let deadline = goal.deadline.flatMap(Day.init(iso:)) {
                draft.hasDeadline = true
                draft.deadline = deadline.chartDate
            }
        case .continuousLong:
            draft.longDistance = TodayText.decimal(goal.distanceKm, fractionDigits: 1)
            draft.pace = goal.paceSecondsPerKm.map(WorkoutFormat.clock) ?? ""
        }
        return draft
    }

    static func values(_ draft: GoalDraft, today: Day, calendar: Calendar = .current) -> Result<GoalValues, GoalDraftError> {
        switch draft.kind {
        case .time:
            guard let seconds = RaceEditorModel.parseClock(draft.time), seconds >= C.minTargetSeconds, seconds <= C.maxTargetSeconds else { return .failure(.time) }
            var deadline: String?
            if draft.hasDeadline {
                let day = Day.today(in: calendar.timeZone, now: draft.deadline)
                guard day >= today else { return .failure(.deadline) }
                deadline = day.iso
            }
            return .success(GoalValues(kind: .time, distanceKm: draft.distanceKm, targetSeconds: seconds, deadline: deadline))
        case .continuousLong:
            guard let distance = Double(draft.longDistance.replacingOccurrences(of: ",", with: ".")), distance > 0, distance <= C.maxDistanceKm else { return .failure(.distance) }
            guard let pace = RaceEditorModel.parseClock(draft.pace), pace >= C.minPace, pace <= C.maxPace else { return .failure(.pace) }
            return .success(GoalValues(kind: .continuousLong, distanceKm: distance, paceSecondsPerKm: pace))
        }
    }

    static func message(_ error: GoalDraftError) -> String {
        switch error {
        case .time: C.invalidTime
        case .distance: C.invalidDistance
        case .pace: C.invalidPace
        case .deadline: C.invalidDeadline
        }
    }

    static func apply(_ values: GoalValues, to goal: GoalRecord, now: Date) {
        let changedTarget = goal.goalKind != values.kind || goal.distanceKm != values.distanceKm || goal.targetSeconds != values.targetSeconds || goal.paceSecondsPerKm != values.paceSecondsPerKm
        goal.goalKind = values.kind
        goal.distanceKm = values.distanceKm
        goal.targetSeconds = values.targetSeconds
        goal.deadline = values.deadline
        goal.paceSecondsPerKm = values.paceSecondsPerKm
        if changedTarget { goal.achievedAt = nil }
        goal.updatedAt = now
    }
}
