import Foundation

public enum LiveStrengthLive {
    private typealias C = LiveStrengthLiveConstants

    public static func card(session: LiveStrengthSession, status: LiveStrengthWatchStatus?) -> LiveStrengthCard {
        let next = LiveStrengthQueue.next(session)
        let exercise = next.flatMap { session.plan.exercise($0.exerciseId) }
        let block = next.flatMap { session.plan.block(containing: $0.exerciseId) }
        let lastDone = lastDoneSet(session)
        return LiveStrengthCard(
            title: session.plan.title,
            setsDone: LiveStrengthQueue.setsDone(session),
            setsTotal: session.plan.totalSets,
            heartRate: status?.heartRate,
            moment: next == nil ? .finished : moment(status?.phase),
            exerciseName: exercise?.name,
            shortName: exercise.map { shortName($0.name) },
            setNumber: next?.round ?? 0,
            setCount: block?.rounds ?? 0,
            exerciseSetsDone: exercise.map { session.done[$0.id]?.count ?? 0 } ?? 0,
            target: next.flatMap { next in exercise.map { target(next, exercise: $0) } },
            last: exercise?.last.first.map { setText($0, bodyweight: exercise?.bodyweight ?? false) },
            lastDone: lastDone.map { setText($0.result, bodyweight: $0.exercise.bodyweight) },
            restEndsAt: status?.restEndsAt,
            restSeconds: lastDone.flatMap { session.plan.block(containing: $0.exercise.id)?.restSeconds }
        )
    }

    static func moment(_ phase: LiveStrengthWatchPhase?) -> LiveStrengthMoment {
        switch phase {
        case .rest, .adjust, .exerciseDone: .resting
        case .restOver: .restOver
        case .paused: .paused
        case .finished: .finished
        case .set, .timed, .pending, nil: .doing
        }
    }

    static func target(_ next: LiveStrengthNextSet, exercise: LiveStrengthExercise) -> String {
        if exercise.kind == .timed, let seconds = next.seconds { return String(seconds) + C.secondsSuffix }
        let reps = next.reps.map(String.init) ?? C.missingReps
        guard let weight = next.weight, weight > 0 else { return exercise.bodyweight ? reps + C.bodyweightSeparator + C.bodyweight : reps }
        return reps + C.times + kilograms(weight)
    }

    static func setText(_ result: LiveStrengthSetResult, bodyweight: Bool) -> String {
        if let seconds = result.seconds, result.reps == nil { return String(seconds) + C.secondsSuffix }
        let reps = result.reps.map(String.init) ?? C.missingReps
        guard let weight = result.weight, weight > 0 else { return bodyweight ? reps + C.bodyweightSeparator + C.bodyweight : reps }
        return reps + C.times + kilograms(weight)
    }

    static func kilograms(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "pt_BR")))
    }

    static func shortName(_ name: String) -> String {
        let words = name.split(separator: " ").prefix(C.shortNameWords).map(String.init)
        let trimmed = words.last.map { C.connectors.contains($0.lowercased()) } == true ? Array(words.dropLast()) : words
        return trimmed.joined(separator: " ")
    }

    private static func lastDoneSet(_ session: LiveStrengthSession) -> (exercise: LiveStrengthExercise, result: LiveStrengthSetResult)? {
        let doneIds = session.events.reversed().lazy.compactMap { event -> String? in
            if case let .setDone(exerciseId, _) = event.action { return exerciseId }
            return nil
        }
        guard let id = doneIds.first, let exercise = session.plan.exercise(id), let result = session.done[id]?.last else { return nil }
        return (exercise, result)
    }
}
