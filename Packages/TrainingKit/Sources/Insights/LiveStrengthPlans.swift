import Foundation
import GarminAPI

public enum LiveStrengthPlans {
    private typealias C = LiveStrengthPlansConstants

    public static func from(
        mfit workout: StrengthWorkout, reader: LiveStrengthMFITReader, history: [String: [LiveStrengthSetResult]] = [:], suggested: [String: Double] = [:],
        bodyweight: Set<String> = []
    ) -> LiveStrengthPlan {
        let blocks = workout.blocks.enumerated().map { index, block in
            let blockId = blockId(index)
            return LiveStrengthBlock(
                id: blockId,
                exercises: block.exercises.enumerated().map { position, exercise in
                    mfitExercise(exercise, id: exerciseId(blockId, position), note: block.note, reader: reader, history: history, suggested: suggested)
                },
                rounds: block.sets,
                restSeconds: Int((block.restSeconds ?? 0).rounded())
            )
        }
        return LiveStrengthPlan(day: workout.day, title: workout.title, source: .mfit, blocks: blocks.map { markBodyweight($0, keys: bodyweight) }, sourceId: workout.id)
    }

    public static func from(
        trainer workout: GeneratedStrengthWorkout, day: String, title: String, history: [String: [LiveStrengthSetResult]] = [:],
        suggested: [String: Double] = [:], bodyweight: Set<String> = []
    ) -> LiveStrengthPlan {
        let blocks = workout.exercises.enumerated().map { index, exercise in
            let blockId = blockId(index)
            let loadKey = StrengthCatalog.canonicalId(exercise.exerciseId)
            let timed = exercise.seconds != nil
            let weight = suggested[loadKey] ?? exercise.weight ?? exercise.suggestedLoad?.weight
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
        return LiveStrengthPlan(day: day, title: title, source: .trainer, blocks: blocks.map { markBodyweight($0, keys: bodyweight) })
    }

    static func mfitExercise(
        _ exercise: StrengthExercise, id: String, note: String?, reader: LiveStrengthMFITReader, history: [String: [LiveStrengthSetResult]],
        suggested: [String: Double] = [:]
    ) -> LiveStrengthExercise {
        let loadKey = reader.loadKey(exercise.name)
        let instruction = exercise.detail ?? note
        let fromNote = (exercise.reps == nil && exercise.seconds == nil) ? note.map(reader.target) : nil
        let reps = exercise.reps ?? fromNote?.reps
        let seconds = exercise.seconds.map { Int($0.rounded()) } ?? fromNote?.seconds
        let timed = seconds != nil && reps == nil
        let last = history[loadKey] ?? []
        let catalog = exercise.exerciseKey == nil ? StrengthCatalogMatch.exercise(named: exercise.name) : nil
        let planned = exercise.weight ?? last.compactMap(\.weight).filter { $0 > 0 }.last
        let weight = [planned, suggested[loadKey]].compactMap { $0 }.max()
        return LiveStrengthExercise(
            id: id,
            name: exercise.name,
            category: catalog?.category ?? exercise.category,
            exerciseKey: exercise.exerciseKey ?? catalog?.id,
            loadKey: loadKey,
            kind: timed ? .timed : .reps,
            reps: timed ? nil : reps,
            seconds: timed ? seconds : nil,
            weight: weight,
            bodyweight: weight == nil,
            perSide: isPerSide(instruction),
            last: last
        )
    }

    static func markBodyweight(_ block: LiveStrengthBlock, keys: Set<String>) -> LiveStrengthBlock {
        var changed = block
        changed.exercises = block.exercises.map { exercise in
            guard keys.contains(exercise.loadKey) else { return exercise }
            var marked = exercise
            marked.bodyweight = true
            marked.weight = nil
            return marked
        }
        return changed
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
