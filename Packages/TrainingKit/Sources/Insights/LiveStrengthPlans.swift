import Foundation
import GarminAPI

public enum LiveStrengthPlans {
    private typealias C = LiveStrengthPlansConstants

    public static func from(mfit workout: StrengthWorkout, reader: LiveStrengthMFITReader, history: [String: [LiveStrengthSetResult]] = [:]) -> LiveStrengthPlan {
        let blocks = workout.blocks.enumerated().map { index, block in
            let blockId = blockId(index)
            return LiveStrengthBlock(
                id: blockId,
                exercises: block.exercises.enumerated().map { position, exercise in
                    mfitExercise(exercise, id: exerciseId(blockId, position), note: block.note, reader: reader, history: history)
                },
                rounds: block.sets,
                restSeconds: Int((block.restSeconds ?? 0).rounded())
            )
        }
        return LiveStrengthPlan(day: workout.day, title: workout.title, source: .mfit, blocks: blocks)
    }

    public static func from(
        trainer workout: GeneratedStrengthWorkout, day: String, title: String, history: [String: [LiveStrengthSetResult]] = [:]
    ) -> LiveStrengthPlan {
        let blocks = workout.exercises.enumerated().map { index, exercise in
            let blockId = blockId(index)
            let loadKey = StrengthCatalog.canonicalId(exercise.exerciseId)
            let timed = exercise.seconds != nil
            let weight = exercise.weight ?? exercise.suggestedLoad?.weight
            let bodyweight = StrengthCatalog.exercise(exercise.exerciseId).map { $0.equipment == .bodyweight } ?? (weight == nil)
            return LiveStrengthBlock(
                id: blockId,
                exercises: [LiveStrengthExercise(
                    id: exerciseId(blockId, 0),
                    name: exercise.name,
                    category: exercise.category,
                    exerciseKey: exercise.exerciseName,
                    loadKey: loadKey,
                    kind: timed ? .timed : .reps,
                    reps: timed ? nil : exercise.reps,
                    seconds: exercise.seconds,
                    weight: weight,
                    bodyweight: bodyweight,
                    perSide: exercise.perSide,
                    last: history[loadKey] ?? []
                )],
                rounds: exercise.sets,
                restSeconds: exercise.restSeconds
            )
        }
        return LiveStrengthPlan(day: day, title: title, source: .trainer, blocks: blocks)
    }

    static func mfitExercise(
        _ exercise: StrengthExercise, id: String, note: String?, reader: LiveStrengthMFITReader, history: [String: [LiveStrengthSetResult]]
    ) -> LiveStrengthExercise {
        let loadKey = reader.loadKey(exercise.name)
        let instruction = exercise.detail ?? note
        let fromNote = (exercise.reps == nil && exercise.seconds == nil) ? note.map(reader.target) : nil
        let reps = exercise.reps ?? fromNote?.reps
        let seconds = exercise.seconds.map { Int($0.rounded()) } ?? fromNote?.seconds
        let timed = seconds != nil && reps == nil
        let last = history[loadKey] ?? []
        return LiveStrengthExercise(
            id: id,
            name: exercise.name,
            category: exercise.category,
            exerciseKey: exercise.exerciseKey,
            loadKey: loadKey,
            kind: timed ? .timed : .reps,
            reps: timed ? nil : reps,
            seconds: timed ? seconds : nil,
            weight: exercise.weight,
            bodyweight: exercise.weight == nil && !last.contains { ($0.weight ?? 0) > 0 },
            perSide: isPerSide(instruction),
            last: last
        )
    }

    static func isPerSide(_ detail: String?) -> Bool {
        guard let text = detail?.lowercased() else { return false }
        return C.perSideKeywords.contains { text.contains($0) }
    }

    static func blockId(_ index: Int) -> String {
        C.blockIdPrefix + String(index + 1)
    }

    static func exerciseId(_ blockId: String, _ position: Int) -> String {
        blockId + C.exerciseIdSeparator + String(position + 1)
    }
}
