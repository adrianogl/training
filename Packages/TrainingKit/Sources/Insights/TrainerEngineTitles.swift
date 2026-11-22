import Foundation
import TrainingCore

private typealias T = TrainerEngineText

extension TrainerEngine {
    public static func retitled(_ plan: TrainerPlan, from first: Day) -> TrainerPlan {
        var result = plan
        result.workouts = plan.workouts.map { workout in
            guard workout.day >= first, workout.kind != .off, workout.totalMeters > 0 else { return workout }
            var renamed = workout
            renamed.title = T.title(kind: workout.kind, meters: workout.totalMeters, method: workout.method, variant: workout.variant)
            return renamed
        }
        return result
    }
}
