import GarminAPI
import Insights
import TrainingCore

enum TrainerExternalMapper {
    private typealias C = TrainerConstants

    static func convert(_ workout: PlannedWorkout) -> TrainerExternalWorkout? {
        guard let day = Day(iso: workout.day) else { return nil }
        let steps = workout.steps.flatMap(convert)
        let meters = workout.estimatedMeters ?? steps.reduce(0.0) { $0 + $1.meters * Double($1.repeats) }
        return TrainerExternalWorkout(day: day, name: workout.title, totalMeters: meters, steps: steps)
    }

    private static func convert(_ step: PlannedStep) -> [TrainerStep] {
        guard !step.children.isEmpty else { return [leaf(step)] }
        if let active = step.children.first(where: { $0.kind == .active }), step.children.count == C.intervalPairCount,
           let rest = step.children.first(where: { $0.kind == .recovery || $0.kind == .rest }), active.children.isEmpty, rest.children.isEmpty {
            var work = leaf(active)
            work.repeats = max(step.repeats, 1)
            var pause = leaf(rest)
            pause.repeats = max(step.repeats - 1, 1)
            return step.repeats > 1 ? [work, pause] : [work]
        }
        let inner = step.children.flatMap(convert)
        return Array(repeating: inner, count: max(step.repeats, 1)).flatMap { $0 }
    }

    private static func leaf(_ step: PlannedStep) -> TrainerStep {
        var low: Double?
        var high: Double?
        if case .pace(let fastest, let slowest) = step.target {
            low = fastest
            high = slowest
        }
        let isRest = step.kind == .rest || (step.kind == .recovery && step.meters == nil && step.seconds != nil)
        var meters = step.meters ?? 0
        if meters == 0, !isRest, let seconds = step.seconds, let low, let high {
            meters = seconds / ((low + high) / 2) * C.metersPerKilometer
        }
        return TrainerStep(
            kind: kind(step.kind), meters: isRest ? 0 : meters, restSeconds: isRest ? step.seconds : nil, paceLow: low, paceHigh: high
        )
    }

    private static func kind(_ kind: PlannedStepKind) -> TrainerStepKind {
        switch kind {
        case .warmup: .warmup
        case .active: .work
        case .recovery, .rest: .recovery
        case .cooldown: .cooldown
        case .other: .steady
        }
    }
}
