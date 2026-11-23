import Foundation

public enum LiveStrengthWatch {
    public static func message(_ plans: [LiveStrengthPlan]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(LiveStrengthWatchMessage(plans: plans.map(watchPlan)))
    }

    public static func history(_ records: [LiveStrengthLoadHistory], before day: String) -> [String: [LiveStrengthSetResult]] {
        let latest = Dictionary(grouping: records.filter { $0.day < day && !$0.loads.isEmpty }, by: \.key)
            .compactMapValues { $0.max { $0.day < $1.day } }
        return latest.mapValues { record in record.loads.map { LiveStrengthSetResult(weight: $0) } }
    }

    static func watchPlan(_ plan: LiveStrengthPlan) -> LiveStrengthWatchPlan {
        LiveStrengthWatchPlan(day: plan.day, title: plan.title, blocks: plan.blocks.map { block in
            LiveStrengthWatchBlock(id: block.id, rounds: block.rounds, restSeconds: block.restSeconds, exercises: block.exercises.map { exercise in
                LiveStrengthWatchExercise(
                    id: exercise.id, name: exercise.name, kind: exercise.kind, reps: exercise.reps, seconds: exercise.seconds,
                    weight: exercise.weight, bodyweight: exercise.bodyweight, perSide: exercise.perSide,
                    last: exercise.last.map { LiveStrengthWatchLast(reps: $0.reps, seconds: $0.seconds, weight: $0.weight) }
                )
            })
        })
    }
}
