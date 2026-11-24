import Foundation

public enum LiveStrengthQueue {
    public static func replay(plan: LiveStrengthPlan, events: [LiveStrengthEvent]) -> LiveStrengthSession {
        var seen = Set<String>()
        let unique = events.filter { seen.insert($0.id).inserted }
        let ordered = unique.sorted { ($0.sequence, $0.id) < ($1.sequence, $1.id) }
        var session = LiveStrengthSession(plan: plan)
        for event in ordered {
            session = apply(event.action, to: session)
        }
        session.events = ordered
        return session
    }

    public static func decodeWatchEvents(_ data: Data) throws -> [LiveStrengthEvent] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode([LiveStrengthEvent].self, from: data)
    }

    public static func receive(_ events: [LiveStrengthEvent], into session: LiveStrengthSession) -> LiveStrengthSession {
        replay(plan: session.plan, events: session.events + events)
    }

    public static func pending(_ session: LiveStrengthSession) -> [LiveStrengthBlock] {
        session.skipped.compactMap { id in
            session.plan.blocks.first { $0.id == id }
        }.filter { !isComplete($0, in: session) }
    }

    public static func current(_ session: LiveStrengthSession) -> LiveStrengthBlock? {
        session.order.lazy.compactMap { id in session.plan.blocks.first { $0.id == id } }
            .first { !isComplete($0, in: session) && !session.leftOut.contains($0.id) }
    }

    public static func next(_ session: LiveStrengthSession) -> LiveStrengthNextSet? {
        guard let block = current(session) else { return nil }
        let counts = block.exercises.map { session.done[$0.id]?.count ?? 0 }
        guard let low = counts.min(), let position = counts.firstIndex(of: low) else { return nil }
        let exercise = block.exercises[position]
        return LiveStrengthNextSet(
            blockId: block.id,
            exerciseId: exercise.id,
            setIndex: low,
            round: low + 1,
            reps: exercise.reps,
            seconds: exercise.seconds,
            weight: plannedWeight(exercise, in: session)
        )
    }

    public static func plannedWeight(_ exercise: LiveStrengthExercise, in session: LiveStrengthSession) -> Double? {
        if let override = session.overrides?[exercise.id] { return override.bodyweight ? nil : override.weight }
        return session.done[exercise.id]?.last?.weight ?? exercise.weight
    }

    public static func effective(_ exercise: LiveStrengthExercise, in session: LiveStrengthSession) -> LiveStrengthExercise {
        guard let override = session.overrides?[exercise.id] else { return exercise }
        var changed = exercise
        changed.bodyweight = override.bodyweight
        changed.weight = override.bodyweight ? nil : override.weight
        return changed
    }

    public static func isComplete(_ block: LiveStrengthBlock, in session: LiveStrengthSession) -> Bool {
        block.exercises.allSatisfy { (session.done[$0.id]?.count ?? 0) >= block.rounds }
    }

    public static func setsDone(_ session: LiveStrengthSession) -> Int {
        session.done.values.reduce(0) { $0 + $1.count }
    }

    static func apply(_ action: LiveStrengthAction, to session: LiveStrengthSession) -> LiveStrengthSession {
        var copy = session
        switch action {
        case let .setDone(exerciseId, result):
            guard session.plan.exercise(exerciseId) != nil else { return session }
            copy.done[exerciseId, default: []].append(result)
            if copy.overrides?[exerciseId]?.nextOnly == true { copy.overrides?[exerciseId] = nil }
        case let .adjust(exerciseId, setIndex, result):
            guard let sets = session.done[exerciseId], sets.indices.contains(setIndex) else { return session }
            var adjusted = result
            adjusted.start = adjusted.start ?? sets[setIndex].start
            adjusted.durationSeconds = adjusted.durationSeconds ?? sets[setIndex].durationSeconds
            copy.done[exerciseId]?[setIndex] = adjusted
        case let .skip(exerciseId):
            guard let block = session.plan.block(containing: exerciseId), !isComplete(block, in: session) else { return session }
            moveToEnd(block.id, in: &copy)
        case let .doNow(exerciseId):
            guard let target = session.plan.block(containing: exerciseId), !isComplete(target, in: session) else { return session }
            let running = current(session)
            guard running?.id != target.id else {
                copy.skipped.removeAll { $0 == target.id }
                return copy
            }
            copy.skipped.removeAll { $0 == target.id }
            copy.leftOut.removeAll { $0 == target.id }
            copy.order.removeAll { $0 == target.id }
            if let running, let index = copy.order.firstIndex(of: running.id) {
                copy.order.insert(target.id, at: index)
                moveToEnd(running.id, in: &copy)
            } else {
                copy.order.insert(target.id, at: 0)
            }
        case let .setWeight(exerciseId, weight, bodyweight, nextOnly):
            guard session.plan.exercise(exerciseId) != nil else { return session }
            var overrides = copy.overrides ?? [:]
            overrides[exerciseId] = LiveStrengthWeightOverride(weight: bodyweight ? nil : weight, bodyweight: bodyweight, nextOnly: nextOnly)
            copy.overrides = overrides
        case let .leaveOut(exerciseId):
            guard let block = session.plan.block(containing: exerciseId) else { return session }
            copy.skipped.removeAll { $0 == block.id }
            if !copy.leftOut.contains(block.id) { copy.leftOut.append(block.id) }
        }
        return copy
    }

    private static func moveToEnd(_ blockId: String, in session: inout LiveStrengthSession) {
        session.order.removeAll { $0 == blockId }
        session.order.append(blockId)
        session.skipped.removeAll { $0 == blockId }
        session.skipped.append(blockId)
    }
}
