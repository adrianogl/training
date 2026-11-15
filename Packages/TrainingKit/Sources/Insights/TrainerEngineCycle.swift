import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static func cycleReview(plan: TrainerPlan, history: TrainerHistory, today: Day) -> TrainerCycleReview? {
        guard let window = cycleWindow(plan: plan, history: history, today: today) else { return nil }
        let first = window.first
        let last = window.last
        let weeks = plan.weeks
            .filter { $0.start >= first && $0.start.adding(days: C.daysPerWeek - 1) <= last }
            .sorted { $0.index < $1.index }
        let workouts = plan.workouts.filter { $0.day >= first && $0.day <= last }
        let longs = workouts.filter { $0.kind == .long }
        let volumes = volumes(of: plan, history: history, today: today)
        let review = TrainerCycleReview(
            first: first, last: last, endedEarly: window.endedEarly,
            weeks: weeks.compactMap { cycleWeek($0, plan: plan, history: history) },
            long: cycleCount(longs, history: history, today: last),
            threshold: cycleCount(workouts.filter { $0.kind == .threshold }, history: history, today: last),
            vo2: cycleCount(workouts.filter { $0.kind == .vo2max }, history: history, today: last),
            mediumLong: cycleCount(workouts.filter { $0.variant == .mediumLong }, history: history, today: last),
            longestLongMeters: longs.compactMap { status(of: $0, history: history, today: last).run?.meters }.max(),
            longestLongPlannedMeters: longs.map(\.totalMeters).max(),
            readinessFirst: averageReadiness(weeks.prefix(C.cycleReadinessWeeks), history: history),
            readinessLast: averageReadiness(weeks.suffix(C.cycleReadinessWeeks), history: history),
            lowReadinessDays: history.readiness.filter { $0.key >= first && $0.key <= last && $0.value < C.cycleLowReadiness }.count,
            extraLightWeeks: plan.lightWeeks.filter { $0 >= first && $0 <= last }.sorted(),
            longsMissed: longs.filter { !longClosed($0, plan: plan, history: history, today: last) }.count,
            predictions: cyclePredictions(plan: plan, history: history, first: first, last: last),
            raceSeconds: cycleRaceSeconds(plan: plan, history: history, first: first, last: last),
            goalSeconds: plan.target.goalSeconds,
            verdict: .keep, reasons: [],
            currentStartMeters: volumes.start, currentPeakMeters: volumes.peak,
            suggestedStartMeters: volumes.start, suggestedPeakMeters: volumes.peak
        )
        return judged(review)
    }

    private static func judged(_ review: TrainerCycleReview) -> TrainerCycleReview {
        var result = review
        result.verdict = .keep
        result.reasons = []
        result.suggestedStartMeters = review.currentStartMeters
        result.suggestedPeakMeters = review.currentPeakMeters
        return result
    }

    private static func cycleWindow(
        plan: TrainerPlan, history: TrainerHistory, today: Day
    ) -> (first: Day, last: Day, endedEarly: Bool)? {
        guard let start = plan.weeks.map(\.start).min(), let lastStart = plan.weeks.map(\.start).max() else { return nil }
        if let ended = plan.endedOn {
            return (start, ended.weekStart.adding(days: -1), true)
        }
        if let date = plan.target.date {
            let raced = today == date && history.runs.contains { $0.day == date }
            guard today > date || raced else { return nil }
            return (start, lastStart.adding(days: C.daysPerWeek - 1), false)
        }
        let length = C.openHorizonWeeks * C.daysPerWeek
        let closed = start.days(until: today) / length
        guard closed > 0 else { return nil }
        let first = start.adding(days: (closed - 1) * length)
        return (first, first.adding(days: length - 1), false)
    }

    private static func cycleWeek(_ week: TrainerWeek, plan: TrainerPlan, history: TrainerHistory) -> TrainerCycleWeek? {
        scoreboard(plan: plan, history: history, week: week.index).map {
            TrainerCycleWeek(index: $0.weekIndex, start: $0.start, doneMeters: $0.doneMeters, plannedMeters: $0.plannedMeters)
        }
    }

    private static func cycleCount(_ workouts: [TrainerWorkout], history: TrainerHistory, today: Day) -> TrainerCycleCount {
        let done = workouts.filter { status(of: $0, history: history, today: today).status == .done }.count
        return TrainerCycleCount(done: done, total: workouts.count)
    }

    private static func averageReadiness(_ weeks: ArraySlice<TrainerWeek>, history: TrainerHistory) -> Double? {
        let values = weeks
            .flatMap { week in (0..<C.daysPerWeek).map { week.start.adding(days: $0) } }
            .compactMap { history.readiness[$0] }
        return values.isEmpty ? nil : Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func cyclePredictions(plan: TrainerPlan, history: TrainerHistory, first: Day, last: Day) -> [TrainerCycleChange] {
        var distances = C.cyclePredictionMeters
        if let goal = plan.target.distanceMeters, !distances.contains(goal) { distances.append(goal) }
        let points = history.predictionSeries
            .filter { $0.key >= first && $0.key <= last }
            .sorted { $0.key < $1.key }
            .map(\.value)
        return distances.compactMap { meters in
            let values = points.compactMap { $0[meters] }
            guard values.count > 1, let start = values.first, let end = values.last else { return nil }
            return TrainerCycleChange(meters: meters, first: start, last: end)
        }
    }

    private static func cycleRaceSeconds(plan: TrainerPlan, history: TrainerHistory, first: Day, last: Day) -> Double? {
        guard let date = plan.target.date, date >= first, date <= last else { return nil }
        let runs = history.runs.filter { $0.day == date }
        return (runs.first { $0.kind == .race } ?? runs.max { $0.meters < $1.meters })?.seconds
    }
}
