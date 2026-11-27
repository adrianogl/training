import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    public static func swapWarning(plan: TrainerPlan, day: Day, other: Day, candidates: [Day]) -> TrainerSwapWarning? {
        guard let conflict = swapConflict(plan.workouts, day, other) else { return nil }
        let alternative = candidates
            .filter { $0 != other && $0 != day }
            .sorted { (abs(day.days(until: $0)), $0) < (abs(day.days(until: $1)), $1) }
            .first { swapConflict(plan.workouts, day, $0) == nil }
        let movedIsLong = plan.workouts.first { $0.day == day }?.kind == .long
        let nextDay = conflict.long.day.adding(days: 1)
        let longMove = !movedIsLong && nextDay.weekStart == conflict.long.day.weekStart
            && plan.workouts.contains { $0.day == nextDay && $0.kind != .race }
            ? nextDay : nil
        return T.swapEveOfLong(conflict, alternative: alternative, longMove: longMove)
    }

    static func swapConflict(_ workouts: [TrainerWorkout], _ first: Day, _ second: Day) -> TrainerSwapConflict? {
        var byDay = Dictionary(workouts.map { ($0.day, $0) }, uniquingKeysWith: { lhs, _ in lhs })
        guard var moved = byDay[first], var swapped = byDay[second] else { return nil }
        moved.day = second
        swapped.day = first
        byDay[second] = moved
        byDay[first] = swapped
        for day in [second, first] {
            guard let workout = byDay[day] else { continue }
            if C.qualityKinds.contains(workout.kind), let long = byDay[day.adding(days: 1)], long.kind == .long {
                return TrainerSwapConflict(quality: workout, long: long)
            }
            if workout.kind == .long, let quality = byDay[day.adding(days: -1)], C.qualityKinds.contains(quality.kind) {
                return TrainerSwapConflict(quality: quality, long: workout)
            }
        }
        return nil
    }
}
