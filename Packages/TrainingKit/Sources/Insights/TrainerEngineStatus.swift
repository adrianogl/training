import Foundation
import Metrics
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static func status(
        of workout: TrainerWorkout, history: TrainerHistory, today: Day
    ) -> (status: TrainerDayStatus, run: TrainerRun?) {
        if workout.day > today { return (.planned, nil) }
        guard let run = history.runs.filter({ $0.day == workout.day }).max(by: { $0.meters < $1.meters }) else {
            if workout.day == today { return (.today, nil) }
            let skippable = workout.kind == .optionalEasy || workout.kind == .off
            return (skippable ? .skipped : .missed, nil)
        }
        guard workout.totalMeters > 0 else { return (.done, run) }
        if run.meters < workout.totalMeters * C.doneShare { return (.partial, run) }
        let isQuality = workout.kind == .threshold || workout.kind == .vo2max
        if isQuality, let on = run.activeOnTarget, let total = run.activeTotal, on < total { return (.offTarget, run) }
        return (.done, run)
    }

    public static func pendingTriggers(_ plan: TrainerPlan, history: TrainerHistory, today: Day) -> [TrainerTrigger] {
        var triggers: [TrainerTrigger] = []
        let previousStart = today.weekStart.adding(days: -C.daysPerWeek)
        if let week = plan.weeks.first(where: { $0.start == previousStart }),
           !plan.versions.contains(where: { $0.trigger == .weekEnded(week.index) }) {
            triggers.append(.weekEnded(week.index))
        }
        for workout in plan.workouts.sorted(by: { $0.day < $1.day }) where workout.day <= today && workout.kind != .off {
            let result = status(of: workout, history: history, today: today)
            guard let run = result.run, !plan.processedActivityIds.contains(run.activityId) else { continue }
            let short = run.meters < workout.totalMeters * C.longFailShare
            let paused = (run.pauses ?? 0) > plannedPauses(of: workout)
            let closesLong = plan.longMode == .blocks && workout.kind == .long
            let lowReadiness = history.readiness[run.day].map { $0 < C.readinessTrigger } ?? false
            if short || result.status == .offTarget || paused || closesLong || lowReadiness {
                triggers.append(.workout(activityId: run.activityId, day: run.day))
            }
        }
        return triggers
    }

    static func findings(
        workouts: [TrainerWorkout], plan: TrainerPlan, history: TrainerHistory, today: Day, readinessDays: [Day], weekly: Bool
    ) -> TrainerFindings {
        var result = TrainerFindings()
        for workout in workouts where workout.day <= today {
            let outcome = status(of: workout, history: history, today: today)
            guard let run = outcome.run, !plan.processedActivityIds.contains(run.activityId) else { continue }
            switch workout.kind {
            case .long:
                let paused = (run.pauses ?? 0) > plannedPauses(of: workout)
                let failed = run.meters < workout.totalMeters * C.longFailShare
                guard failed || paused else { continue }
                result.longPlanned = workout.totalMeters
                result.longDone = run.meters
                result.longDay = workout.day
                result.longFailed = failed
                result.longPaused = paused
                result.longReduced = run.meters < workout.totalMeters * C.longReduceShare
            case .threshold, .vo2max:
                if outcome.status == .offTarget, let on = run.activeOnTarget, let total = run.activeTotal {
                    result.misses.append(TrainerQualityMiss(kind: workout.kind, day: workout.day, onTarget: on, total: total))
                }
            default:
                break
            }
        }
        let values = readinessDays.compactMap { history.readiness[$0] }.map(Double.init)
        result.readiness = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        if let value = result.readiness {
            result.lowReadiness = weekly ? value < C.readinessWeek : value < Double(C.readinessTrigger)
        }
        return result
    }
}
