import Foundation
import Insights
import TrainingCore

struct TrainerLegSwap: Equatable {
    let quality: TrainerWorkout
    let easy: TrainerWorkout
    let strengthName: String
    let strengthDay: Day
}

enum TrainerLegSwapFinder {
    private typealias C = TrainerMFITConstants

    static func find(plan: TrainerPlan, today: Day, kept: Set<String>) -> TrainerLegSwap? {
        let heavy = Dictionary(plan.strength.filter { $0.legLoad == .heavy || $0.group == .lower }.map { ($0.weekday, $0.name) }) { first, _ in first }
        guard !heavy.isEmpty else { return nil }
        let weekday: (Day) -> Int = { $0.weekStart.days(until: $0) + 1 }
        let afterHeavy: (Day) -> String? = { day in heavy[weekday(day.adding(days: -1))] }
        let upcoming = plan.workouts.filter { $0.day >= today && $0.day < today.weekStart.adding(days: 14) }
        for quality in upcoming.sorted(by: { $0.day < $1.day }) where C.qualityKinds.contains(quality.kind.rawValue) && !kept.contains(quality.day.iso) {
            guard let name = afterHeavy(quality.day) else { continue }
            let candidates = upcoming.filter { easy in
                C.easyKinds.contains(easy.kind.rawValue) && easy.day.weekStart == quality.day.weekStart
                    && afterHeavy(easy.day) == nil && heavy[weekday(easy.day)] == nil
            }
            guard let easy = candidates.min(by: { abs($0.day.days(until: quality.day)) < abs($1.day.days(until: quality.day)) }) else { continue }
            return TrainerLegSwap(quality: quality, easy: easy, strengthName: name, strengthDay: quality.day.adding(days: -1))
        }
        return nil
    }

    static func apply(_ swap: TrainerLegSwap, to plan: TrainerPlan, now: Date) -> TrainerPlan {
        var next = plan
        next.workouts = plan.workouts.map { workout in
            var moved = workout
            if workout.day == swap.quality.day { moved.day = swap.easy.day; moved.edited = true }
            if workout.day == swap.easy.day { moved.day = swap.quality.day; moved.edited = true }
            return moved
        }.sorted { $0.day < $1.day }
        let reason = TrainerMFITText.swapReason(swap)
        next.versions.append(TrainerVersion(
            number: (plan.versions.last?.number ?? 0) + 1,
            createdAt: now,
            trigger: .strengthChanged,
            summary: reason,
            changes: [
                TrainerChange(kind: .moved, day: swap.easy.day, title: swap.quality.title, before: TrainerMFITText.dayName(swap.quality.day), after: TrainerMFITText.dayName(swap.easy.day), reason: reason),
                TrainerChange(kind: .moved, day: swap.quality.day, title: swap.easy.title, before: TrainerMFITText.dayName(swap.easy.day), after: TrainerMFITText.dayName(swap.quality.day), reason: reason),
            ]
        ))
        return next
    }
}
