import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    public static func refreshingRules(_ plan: TrainerPlan, history: TrainerHistory, today: Day, now: Date) -> TrainerPlan? {
        guard plan.rulesVersion != C.prescriptionRulesVersion, plan.endedOn == nil else { return nil }
        let paces = resolvedPaces(history: history, today: today, target: plan.target, overrides: plan.paceOverrides)
        var long = plan.longPlan
        if long.mode == .blocks { long.evidence = longEvidence(history: history, plan: plan, today: today) }
        let keptByReadiness = readinessDays(plan, today: today)
        let generated = detailWorkouts(
            weeks: plan.weeks, structure: plan.structure, paces: paces, history: history, target: plan.target, today: today,
            past: plan.workouts.filter { $0.day <= today }, requests: activeRequests(of: plan, today: today),
            peakVolume: chosenVolumes(plan, history: history, today: today).peak, long: long
        ).map { item in
            keptByReadiness.contains(item.day) ? plan.workouts.first { $0.day == item.day } ?? item : item
        }
        let protected = protectingEdited(
            existing: plan.workouts, generated: generated, history: history, keepDone: true, notify: { $0 >= today }
        )
        let merged = plan.workouts.filter { $0.day < today } + protected.workouts
        let weeks = withPlannedMeters(
            plan.weeks, workouts: merged, structure: plan.structure, target: plan.target, history: history, today: today, paces: paces
        )
        var changes = groupingDistant(
            workoutChanges(
                old: plan.workouts.filter { $0.day >= today }, new: protected.workouts,
                reasons: TrainerChangeReasons(override: T.rulesRefreshed)
            ),
            today: today, weeks: weeks
        ) + protected.notices
        if changes.isEmpty {
            changes = [TrainerChange(kind: .unchanged, title: T.unchangedTitle, reason: T.rulesRefreshed)]
        }
        var refreshed = finish(
            plan, weeks: weeks, workouts: merged, paces: paces, processed: plan.processedActivityIds,
            trigger: .request(TrainerRequest(category: .other, text: "", from: today)), now: now, summary: T.rulesRefreshed,
            changes: changes
        )
        refreshed.rulesVersion = C.prescriptionRulesVersion
        return refreshed
    }

    public static func isRulesRefresh(_ trigger: TrainerTrigger) -> Bool {
        guard case .request(let request) = trigger else { return false }
        return request.category == .other && request.text.isEmpty
    }

    private static func readinessDays(_ plan: TrainerPlan, today: Day) -> Set<Day> {
        Set(plan.versions.flatMap { version -> [Day] in
            guard case .readiness(let day, _) = version.trigger, day == today else { return [] }
            return version.changes.compactMap(\.day)
        })
    }
}
