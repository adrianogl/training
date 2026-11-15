import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static let cycleLowReadiness = C.cycleLowReadiness

    public static func cycleReview(plan: TrainerPlan, history: TrainerHistory, today: Day) -> TrainerCycleReview? {
        guard let window = cycleWindow(plan: plan, history: history, today: today) else { return nil }
        let first = window.first
        let last = window.last
        let weeks = plan.weeks
            .filter { $0.start >= first && $0.start.adding(days: C.daysPerWeek - 1) <= last }
            .sorted { $0.index < $1.index }
        let reference = min(today, last)
        let workouts = plan.workouts.filter { $0.day >= first && $0.day <= reference }
        let longs = workouts.filter { $0.kind == .long }
        let volumes = cycleVolumes(weeks, plan: plan, history: history, today: today)
        let review = TrainerCycleReview(
            first: first, last: last, endedEarly: window.endedEarly,
            weeks: weeks.compactMap { cycleWeek($0, plan: plan, history: history) },
            long: cycleCount(longs, history: history, today: reference),
            threshold: cycleCount(workouts.filter { $0.kind == .threshold }, history: history, today: reference),
            vo2: cycleCount(workouts.filter { $0.kind == .vo2max }, history: history, today: reference),
            mediumLong: cycleCount(workouts.filter { $0.variant == .mediumLong }, history: history, today: reference),
            longestLongMeters: longs.compactMap { status(of: $0, history: history, today: reference).run?.meters }.max(),
            longestLongPlannedMeters: longs.map(\.totalMeters).max(),
            readinessFirst: averageReadiness(weeks.prefix(C.cycleReadinessWeeks), history: history),
            readinessLast: averageReadiness(weeks.suffix(C.cycleReadinessWeeks), history: history),
            lowReadinessDays: history.readiness.filter { $0.key >= first && $0.key <= last && $0.value < C.cycleLowReadiness }.count,
            extraLightWeeks: plan.lightWeeks.filter { $0 >= first && $0 <= last }.sorted(),
            longsMissed: longs.filter { !longClosed($0, plan: plan, history: history, today: reference) }.count,
            predictions: cyclePredictions(plan: plan, history: history, first: first, last: last),
            raceSeconds: cycleRaceSeconds(plan: plan, history: history, first: first, last: last),
            goalSeconds: plan.target.goalSeconds,
            verdict: .keep, reasons: [],
            currentStartMeters: volumes.start, currentPeakMeters: volumes.peak,
            suggestedStartMeters: volumes.start, suggestedPeakMeters: volumes.peak
        )
        return judged(review, goalMeters: plan.target.distanceMeters)
    }

    private static func cycleVolumes(
        _ weeks: [TrainerWeek], plan: TrainerPlan, history: TrainerHistory, today: Day
    ) -> (start: Double, peak: Double) {
        guard let first = weeks.first, let peak = weeks.map(\.targetMeters).max() else {
            return volumes(of: plan, history: history, today: today)
        }
        return (first.targetMeters, max(first.targetMeters, peak))
    }

    private static func judged(_ review: TrainerCycleReview, goalMeters: Double?) -> TrainerCycleReview {
        var result = review
        let outcome = cycleVerdict(review, goalMeters: goalMeters)
        result.verdict = outcome.verdict
        result.reasons = outcome.reasons
        switch outcome.verdict {
        case .increase:
            result.suggestedStartMeters = floorKilometers(review.currentStartMeters * C.cycleIncreaseFactor)
            result.suggestedPeakMeters = floorKilometers(review.currentPeakMeters * C.cycleIncreaseFactor)
        case .decrease:
            result.suggestedStartMeters = floorKilometers(review.currentStartMeters * C.cycleDecreaseFactor)
            result.suggestedPeakMeters = floorKilometers(review.currentPeakMeters * C.cycleDecreaseFactor)
        case .keep:
            result.suggestedStartMeters = review.currentStartMeters
            result.suggestedPeakMeters = review.currentPeakMeters
        }
        return result
    }

    static func cycleVerdict(
        _ review: TrainerCycleReview, goalMeters: Double? = nil
    ) -> (verdict: TrainerCycleVerdict, reasons: [TrainerCycleReason]) {
        guard review.weeks.count >= C.cycleMinimumWeeks else {
            return (.keep, [.tooShort(weeks: review.weeks.count)])
        }
        let share = review.doneShare
        let weeksBelow = review.weeks.filter { $0.doneMeters < $0.plannedMeters * C.cycleWeekBelowShare }.count
        let readinessFall: Double?
        if let first = review.readinessFirst, let last = review.readinessLast { readinessFall = first - last } else { readinessFall = nil }
        let reference = referencePrediction(review, goalMeters: goalMeters)
        let improved = reference.map { $0.last < $0.first } ?? true
        let lightWeeks = review.extraLightWeeks.count

        let verdict: TrainerCycleVerdict
        if share < C.cycleDecreaseShare || (readinessFall ?? 0) >= C.cycleReadinessDrop || lightWeeks >= 2 {
            verdict = .decrease
        } else if share >= C.cycleIncreaseShare, (readinessFall ?? 0) <= C.cycleReadinessTolerance, improved, lightWeeks <= 1 {
            verdict = .increase
        } else {
            verdict = .keep
        }

        var reasons: [TrainerCycleReason] = [.volume(share: share, weeksBelow: weeksBelow)]
        if verdict == .keep, share >= C.cycleIncreaseShare, !improved { reasons.append(.noProgress) }
        if let first = review.readinessFirst, let last = review.readinessLast { reasons.append(.readiness(first: first, last: last)) }
        if lightWeeks > 0 { reasons.append(.lightWeeks(lightWeeks)) }
        if let seconds = review.raceSeconds, let goal = review.goalSeconds {
            reasons.append(.race(seconds: seconds, goal: goal))
        } else if let reference {
            reasons.append(.prediction(reference))
        }
        return (verdict, Array(reasons.prefix(C.cycleMaximumReasons)))
    }

    private static func referencePrediction(_ review: TrainerCycleReview, goalMeters: Double?) -> TrainerCycleChange? {
        if let goalMeters, let match = review.predictions.min(by: { abs($0.meters - goalMeters) < abs($1.meters - goalMeters) }) {
            return match
        }
        return review.predictions.first { $0.meters == C.cycleReferencePredictionMeters } ?? review.predictions.first
    }

    private static func cycleWindow(
        plan: TrainerPlan, history: TrainerHistory, today: Day
    ) -> (first: Day, last: Day, endedEarly: Bool)? {
        guard let start = plan.weeks.map(\.start).min(), let lastStart = plan.weeks.map(\.start).max() else { return nil }
        let length = C.openHorizonWeeks * C.daysPerWeek
        let wholePlan = (start, lastStart.adding(days: C.daysPerWeek - 1), false)
        if let ended = plan.endedOn {
            let last = ended.weekStart.adding(days: -1)
            if let date = plan.target.date {
                return ended >= date ? wholePlan : (start, last, true)
            }
            let block = max(0, start.days(until: last)) / length
            return (start.adding(days: block * length), last, true)
        }
        if let date = plan.target.date {
            let raced = today == date && history.runs.contains { $0.day == date }
            guard today > date || raced else { return nil }
            return wholePlan
        }
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
        let distances = C.cyclePredictionMeters + [plan.target.distanceMeters].compactMap { $0 }
        let points = history.predictionSeries
            .filter { $0.key >= first && $0.key <= last }
            .sorted { $0.key < $1.key }
            .map(\.value)
        guard points.count > 1, let firstPoint = points.first, let lastPoint = points.last else { return [] }
        var changes: [TrainerCycleChange] = []
        for distance in distances {
            guard let start = nearest(firstPoint, to: distance), let end = nearest(lastPoint, to: distance),
                  start.meters == end.meters, !changes.contains(where: { $0.meters == start.meters }) else { continue }
            changes.append(TrainerCycleChange(meters: start.meters, first: start.seconds, last: end.seconds))
        }
        return changes
    }

    private static func cycleRaceSeconds(plan: TrainerPlan, history: TrainerHistory, first: Day, last: Day) -> Double? {
        guard let date = plan.target.date, date >= first, date <= last else { return nil }
        let runs = history.runs.filter { $0.day == date }
        return (runs.first { $0.kind == .race } ?? runs.max { $0.meters < $1.meters })?.seconds
    }
}
