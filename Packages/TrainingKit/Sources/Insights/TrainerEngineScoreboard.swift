import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static func scoreboard(plan: TrainerPlan, history: TrainerHistory, week index: Int) -> TrainerScoreboard? {
        guard let week = plan.weeks.first(where: { $0.index == index }) else { return nil }
        let days = (0..<C.daysPerWeek).map { week.start.adding(days: $0) }
        let end = week.start.adding(days: C.daysPerWeek - 1)
        let workouts = plan.workouts.filter { days.contains($0.day) }
        let doneMeters = history.runs.filter { days.contains($0.day) }.reduce(0.0) { $0 + $1.meters }
        let plannedMeters = workouts.isEmpty ? week.plannedMeters : workouts.reduce(0.0) { $0 + $1.totalMeters }
        let quality = workouts.filter { $0.kind == .threshold || $0.kind == .vo2max }
        let onTarget = quality.filter { status(of: $0, history: history, today: end).status == .done }.count
        let long = workouts.first { $0.kind == .long }
        let prediction = predictionChange(plan: plan, history: history, week: week)
        return TrainerScoreboard(
            weekIndex: week.index, start: week.start, doneMeters: doneMeters, plannedMeters: plannedMeters,
            qualityOnTarget: onTarget, qualityTotal: quality.count,
            longClosed: long.map { longClosed($0, plan: plan, history: history, today: end) },
            longBlocks: plan.longMode == .blocks,
            predictionDeltaSeconds: prediction?.seconds, predictionMeters: prediction?.meters
        )
    }

    public static func scoreboards(plan: TrainerPlan, history: TrainerHistory, today: Day) -> [TrainerScoreboard] {
        plan.weeks
            .filter { $0.start.adding(days: C.daysPerWeek) <= today }
            .sorted { $0.index > $1.index }
            .compactMap { scoreboard(plan: plan, history: history, week: $0.index) }
    }

    private static func longClosed(_ workout: TrainerWorkout, plan: TrainerPlan, history: TrainerHistory, today: Day) -> Bool {
        guard let run = status(of: workout, history: history, today: today).run else { return false }
        guard run.meters >= workout.totalMeters * C.doneShare, (run.pauses ?? 0) <= plannedPauses(of: workout) else { return false }
        return !(plan.longMode == .blocks && run.fadeKm != nil)
    }

    private static func predictionChange(plan: TrainerPlan, history: TrainerHistory, week: TrainerWeek) -> (meters: Double, seconds: Double)? {
        guard let distance = plan.target.distanceMeters else { return nil }
        let series = history.predictionSeries
        let before = series.keys.filter { $0 <= week.start }.max()
        let after = series.keys.filter { $0 <= week.start.adding(days: C.daysPerWeek) }.max()
        guard let before, let after, before != after,
              let first = nearest(series[before] ?? [:], to: distance), let last = nearest(series[after] ?? [:], to: distance),
              first.meters == last.meters else { return nil }
        return (last.meters, last.seconds - first.seconds)
    }

    private static func nearest(_ values: [Double: Double], to distance: Double) -> (meters: Double, seconds: Double)? {
        values.min { abs($0.key - distance) < abs($1.key - distance) }.map { ($0.key, $0.value) }
    }
}
