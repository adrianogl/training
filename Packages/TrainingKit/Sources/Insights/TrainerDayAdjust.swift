import Foundation
import TrainingCore

private typealias C = TrainerDayAdjustConstants
private typealias D = DayAdjustConstants
private typealias T = TrainerEngineText

public enum TrainerDayAdjust {
    public static func adjust(_ workout: TrainerWorkout, entries: DayAdjustEntries) -> TrainerDayAdjustResult {
        guard let factors = DayAdjust.factors(
            score: entries.score, temperature: entries.temperature, dewPoint: entries.dewPoint, radiation: entries.radiation,
            hotSessions: entries.hotSessions, heavyLegs: entries.heavyLegs
        ) else { return .rest }
        let total: Int
        let reasons: [DayAdjustReason]
        switch DayAdjust.decide(factors, meanPaces: activeRanges(workout).map(mean)) {
        case let .swap(list): return .swap(reasons: list)
        case let .apply(seconds, list):
            total = seconds
            reasons = list
        }

        var result = workout
        var didShorten = false
        if factors.shorten {
            result = shortened(workout, shape: shape(workout))
            didShorten = result.steps != workout.steps || result.totalMeters != workout.totalMeters
        }
        if total == 0, !didShorten { return .none }

        let original = activeRanges(result)
        result = shifted(result, fixed: factors.fixedSeconds, heatShare: factors.heatShare ?? 0)
        return .adjusted(TrainerDayAdjustment(
            workout: result, original: original, originalPace: workoutRange(workout), seconds: total, reasons: reasons, shortened: didShorten
        ))
    }

    public static func shape(_ workout: TrainerWorkout) -> DayAdjustShape {
        if workout.kind == .long { return .long }
        let actives = workout.steps.filter(isActive)
        if actives.contains(where: { $0.repeats > 1 }) || activeBlocks(workout) > 1 { return .intervals }
        return .continuous
    }

    public static func isActive(_ step: TrainerStep) -> Bool {
        C.activeKinds.contains(step.kind)
    }

    public static func activeRanges(_ workout: TrainerWorkout) -> [TrainerPaceRange] {
        guard !workout.steps.isEmpty else { return workoutRange(workout).map { [$0] } ?? [] }
        return workout.steps.filter(isActive).compactMap { range($0, in: workout) }
    }

    public static func differs(_ lhs: TrainerDayAdjustResult, _ rhs: TrainerDayAdjustResult) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none), (.rest, .rest), (.swap, .swap): false
        case let (.adjusted(left), .adjusted(right)):
            abs(left.seconds - right.seconds) >= C.minimumChangeSeconds || left.shortened != right.shortened
        case let (.adjusted(change), .none), let (.none, .adjusted(change)):
            change.seconds >= C.minimumChangeSeconds || change.shortened
        default: true
        }
    }

    public static func heatShare(_ entries: DayAdjustEntries) -> Double {
        guard let temperature = entries.temperature, let dewPoint = entries.dewPoint else { return 0 }
        return WeatherAdjustment.heatShare(
            temperature: temperature, dewPoint: dewPoint, radiation: entries.radiation, hotSessions: entries.hotSessions
        )
    }

    public static func includedHeatShare(_ result: TrainerDayAdjustResult, entries: DayAdjustEntries) -> Double {
        guard case let .adjusted(change) = result,
              change.reasons.contains(where: { if case .heat = $0 { true } else { false } }) else { return 0 }
        return heatShare(entries)
    }

    private static func mean(_ range: TrainerPaceRange) -> Double {
        (range.low + range.high) / 2
    }

    private static func workoutRange(_ workout: TrainerWorkout) -> TrainerPaceRange? {
        guard let low = workout.paceLow, let high = workout.paceHigh else { return nil }
        return TrainerPaceRange(low: low, high: high)
    }

    private static func range(_ step: TrainerStep, in workout: TrainerWorkout) -> TrainerPaceRange? {
        guard let low = step.paceLow ?? workout.paceLow, let high = step.paceHigh ?? workout.paceHigh else { return nil }
        return TrainerPaceRange(low: low, high: high)
    }

    private static func activeBlocks(_ workout: TrainerWorkout) -> Int {
        let steps = workout.steps
        return steps.indices.filter { index in
            guard isActive(steps[index]) else { return false }
            guard index > 0, isActive(steps[index - 1]) else { return true }
            return range(steps[index - 1], in: workout) != range(steps[index], in: workout)
        }.count
    }

    private static func isSplitContinuous(_ workout: TrainerWorkout) -> Bool {
        let actives = workout.steps.filter(isActive)
        let count = actives.reduce(0) { $0 + max($1.repeats, 1) }
        let paused = workout.steps.contains { $0.kind == .recovery || (isActive($0) && ($0.restSeconds ?? 0) > 0) }
        return count > 1 && !paused && activeBlocks(workout) == 1
    }

    private static func shifted(_ workout: TrainerWorkout, fixed: Int, heatShare: Double) -> TrainerWorkout {
        func offset(_ range: TrainerPaceRange) -> Double {
            Double(fixed + DayAdjust.heatOffset(mean(range), share: heatShare))
        }
        var result = workout
        result.steps = workout.steps.map { step in
            guard isActive(step), let range = range(step, in: workout) else { return step }
            var moved = step
            moved.paceLow = range.low + offset(range)
            moved.paceHigh = range.high + offset(range)
            return moved
        }
        if let range = workoutRange(workout) {
            result.paceLow = range.low + offset(range)
            result.paceHigh = range.high + offset(range)
        }
        return result
    }

    private static func shortened(_ workout: TrainerWorkout, shape: DayAdjustShape) -> TrainerWorkout {
        var result = workout
        if workout.steps.isEmpty {
            guard shape != .intervals else { return workout }
            result.totalMeters = rounded(workout.totalMeters * D.shortenShare)
        } else {
            switch shape {
            case .intervals: result.steps = droppingRepeat(workout.steps)
            case .continuous: result.steps = scalingActive(workout.steps, onlyLast: false)
            case .long: result.steps = scalingActive(workout.steps, onlyLast: !isSplitContinuous(workout))
            }
            result.totalMeters = workout.totalMeters - stepsMeters(workout.steps) + stepsMeters(result.steps)
        }
        guard result.totalMeters != workout.totalMeters else { return result }
        let base = T.title(kind: workout.kind, meters: workout.totalMeters, method: workout.method, variant: workout.variant)
        if workout.title.hasPrefix(base) {
            result.title = T.title(kind: workout.kind, meters: result.totalMeters, method: workout.method, variant: workout.variant)
                + workout.title.dropFirst(base.count)
        }
        return result
    }

    private static func droppingRepeat(_ steps: [TrainerStep]) -> [TrainerStep] {
        var result = steps
        if let index = steps.firstIndex(where: { isActive($0) && $0.repeats > 1 }) {
            let repeats = steps[index].repeats
            result[index].repeats = repeats - 1
            let next = index + 1
            if next < steps.count, steps[next].kind == .recovery, steps[next].repeats == repeats - 1 {
                if repeats - 2 > 0 {
                    result[next].repeats = repeats - 2
                } else {
                    result.remove(at: next)
                }
            }
            return result
        }
        let actives = steps.indices.filter { isActive(steps[$0]) }
        guard actives.count > 1, let last = actives.last else { return steps }
        result.remove(at: last)
        if last > 0, result[last - 1].kind == .recovery { result.remove(at: last - 1) }
        return result
    }

    private static func scalingActive(_ steps: [TrainerStep], onlyLast: Bool) -> [TrainerStep] {
        let lastIndex = steps.lastIndex(where: isActive)
        return steps.enumerated().map { index, step in
            guard isActive(step), step.meters > 0, !onlyLast || index == lastIndex else { return step }
            var result = step
            result.meters = rounded(step.meters * D.shortenShare)
            return result
        }
    }

    private static func rounded(_ meters: Double) -> Double {
        (meters / D.roundingMeters).rounded() * D.roundingMeters
    }

    private static func stepsMeters(_ steps: [TrainerStep]) -> Double {
        steps.reduce(0.0) { $0 + $1.meters * Double($1.repeats) }
    }
}
