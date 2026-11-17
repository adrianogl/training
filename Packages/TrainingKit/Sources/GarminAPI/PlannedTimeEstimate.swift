import Foundation
import TrainingCore

public enum PlannedTimeEstimate {
    public static func total(_ plan: PlannedWorkout, fallback: PaceBand?) -> RunTimeRange? {
        RunTimeEstimate.total(plan.steps.flatMap(\.flattened).map(part), fallback: fallback)
    }

    public static func single(_ step: PlannedStep) -> RunTimeRange? {
        guard step.children.isEmpty, step.seconds == nil, let meters = step.meters, let pace = pace(step) else { return nil }
        return RunTimeEstimate.total([.distance(meters: meters, pace: pace)], fallback: nil)
    }

    static func part(_ step: PlannedStep) -> RunTimePart {
        if let seconds = step.seconds { return .fixed(seconds: seconds) }
        if let meters = step.meters { return .distance(meters: meters, pace: pace(step)) }
        return .open
    }

    static func pace(_ step: PlannedStep) -> PaceBand? {
        guard case .pace(let fastest, let slowest) = step.target else { return nil }
        return PaceBand(fastest: fastest, slowest: slowest)
    }
}
