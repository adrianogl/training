import Foundation
import TrainingCore

extension TrainerEngine {
    public static func fillMissingWeeks(_ plan: TrainerPlan, history: TrainerHistory, today: Day) -> TrainerPlan? {
        let covered = Set(plan.workouts.map(\.day))
        let missing = Set(plan.weeks.map(\.start).filter { start in
            start >= today.weekStart && (0..<TrainerEngineConstants.daysPerWeek).contains { offset in
                let day = start.adding(days: offset)
                return day >= today && !covered.contains(day)
            }
        })
        guard !missing.isEmpty else { return nil }
        let paces = resolvedPaces(history: history, today: today, target: plan.target, overrides: plan.paceOverrides)
        let volumes = chosenVolumes(plan, history: history, today: today)
        var long = plan.longPlan
        if long.mode == .blocks { long.evidence = longEvidence(history: history, plan: plan, today: today) }
        let generated = detailWorkouts(
            weeks: plan.weeks, structure: plan.structure, paces: paces, history: history, target: plan.target, today: today,
            past: plan.workouts.filter { $0.day <= today }, requests: activeRequests(of: plan, today: today),
            peakVolume: volumes.peak, long: long
        ).filter { missing.contains($0.day.weekStart) && !covered.contains($0.day) }
        guard !generated.isEmpty else { return nil }
        let merged = (plan.workouts + generated).sorted { $0.day < $1.day }
        let weeks = withPlannedMeters(
            plan.weeks, workouts: merged, structure: plan.structure, target: plan.target, history: history, today: today, paces: paces
        )
        var result = plan
        result.workouts = merged
        result.weeks = zip(plan.weeks, weeks).map { missing.contains($0.0.start) ? $0.1 : $0.0 }
        return result
    }
}
