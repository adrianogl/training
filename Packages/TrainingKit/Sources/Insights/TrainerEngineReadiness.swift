import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    public static func readinessSuggestion(
        plan: TrainerPlan, history: TrainerHistory, today: Day, factor: TrainerReadinessFactor? = nil
    ) -> TrainerReadinessSuggestion? {
        guard let score = history.readiness[today] else { return nil }
        return readinessSuggestion(plan: plan, history: history, today: today, score: score, factor: factor)
    }

    static func readinessSuggestion(
        plan: TrainerPlan, history: TrainerHistory, today: Day, score: Int, factor: TrainerReadinessFactor?
    ) -> TrainerReadinessSuggestion? {
        guard score < C.readinessTrigger,
              let workout = plan.workouts.first(where: { $0.day == today }),
              C.readinessStrongKinds.contains(workout.kind), !workout.edited,
              !history.runs.contains(where: { $0.day == today }) else { return nil }
        let tomorrow = today.adding(days: 1)
        let next = plan.workouts.first { $0.day == tomorrow }
        let swaps = next.map { ($0.kind == .easy || $0.kind == .optionalEasy) && !$0.edited } ?? false
        return TrainerReadinessSuggestion(
            day: today, score: score, factor: factor, workoutTitle: workout.title, swapDay: swaps ? tomorrow : nil
        )
    }

    static func applyReadiness(
        _ plan: TrainerPlan, day: Day, score: Int, history: TrainerHistory, today: Day, now: Date
    ) -> TrainerPlan {
        guard day == today,
              let suggestion = readinessSuggestion(plan: plan, history: history, today: today, score: score, factor: nil),
              let index = plan.workouts.firstIndex(where: { $0.day == day }) else { return plan }
        var workouts = plan.workouts
        let strong = workouts[index]
        let easy = easyWorkout(day: day, meters: C.readinessEasyMeters, paces: plan.paces, rationale: T.readinessEasyRationale(score))
        workouts[index] = easy
        var changes = [TrainerChange(
            kind: .changed, day: day, title: changeTitle(strong), before: describe(strong), after: describe(easy),
            reason: T.readinessReason(score)
        )]
        if let swapDay = suggestion.swapDay, let other = workouts.firstIndex(where: { $0.day == swapDay }) {
            let previous = workouts[other]
            var moved = strong
            moved.day = swapDay
            workouts[other] = moved
            changes.append(TrainerChange(
                kind: .moved, day: swapDay, title: changeTitle(moved), before: describe(previous), after: describe(moved),
                reason: T.readinessReason(score)
            ))
        }
        let weeks = withPlannedMeters(
            plan.weeks, workouts: workouts, structure: plan.structure, target: plan.target, history: history, today: today
        )
        return finish(
            plan, weeks: weeks, workouts: workouts, paces: plan.paces, processed: plan.processedActivityIds,
            trigger: .readiness(day: day, score: score), now: now,
            summary: T.readinessSummary(score, swapped: suggestion.swaps), changes: changes
        )
    }
}
