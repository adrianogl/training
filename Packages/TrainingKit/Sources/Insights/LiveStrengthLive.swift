import Foundation

public enum LiveStrengthLive {
    private typealias C = LiveStrengthLiveConstants

    public static func card(session: LiveStrengthSession, status: LiveStrengthWatchStatus?) -> LiveStrengthCard {
        let next = LiveStrengthQueue.next(session)
        let exercise = next.flatMap { session.plan.exercise($0.exerciseId) }.map { LiveStrengthQueue.effective($0, in: session) }
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

    public static func screen(session: LiveStrengthSession) -> LiveStrengthScreen {
        let next = LiveStrengthQueue.next(session)
        let labels = markers(session.plan)
        let now = next.flatMap { next -> LiveStrengthNow? in
            guard let planned = session.plan.exercise(next.exerciseId), let block = session.plan.block(containing: next.exerciseId),
                  let label = labels[planned.id] else { return nil }
            let exercise = LiveStrengthQueue.effective(planned, in: session)
            return LiveStrengthNow(
                number: label.number, marker: label.marker, exercise: exercise, rounds: block.rounds, restSeconds: block.restSeconds,
                rows: rows(exercise, rounds: block.rounds, next: next, session: session),
                round: block.isSuperset ? round(block, letter: label.superset ?? "", labels: labels, session: session) : nil
            )
        }
        let nowBlock = next.flatMap { session.plan.block(containing: $0.exerciseId) }?.id
        let items = session.order.compactMap { id in session.plan.blocks.first { $0.id == id } }.flatMap { block in
            block.exercises.compactMap { planned -> LiveStrengthItem? in
                guard block.id != nowBlock else { return nil }
                let exercise = LiveStrengthQueue.effective(planned, in: session)
                let done = session.done[exercise.id]?.count ?? 0
                let state: LiveStrengthItemState = done >= block.rounds ? .done
                    : session.leftOut.contains(block.id) ? .leftOut
                    : session.skipped.contains(block.id) ? .skipped : .pending
                let label = labels[exercise.id]
                return LiveStrengthItem(
                    number: label?.number ?? 0, marker: label?.marker ?? "", blockId: block.id, superset: label?.superset,
                    restSeconds: block.restSeconds, exercise: exercise, rounds: block.rounds, setsDone: done, state: state
                )
            }
        }
        return LiveStrengthScreen(now: now, items: items)
    }

    static func round(
        _ block: LiveStrengthBlock, letter: String, labels: [String: (number: Int, marker: String, superset: String?)], session: LiveStrengthSession
    ) -> LiveStrengthRound {
        let exercises = block.exercises.map { LiveStrengthQueue.effective($0, in: session) }
        let counts = exercises.map { session.done[$0.id]?.count ?? 0 }
        let current = counts.min() ?? 0
        let reference = exercises.first { !$0.last.isEmpty }
        let rows = (0..<block.rounds).map { index -> LiveStrengthRoundRow in
            let cells = exercises.map { exercise -> String in
                let done = session.done[exercise.id] ?? []
                if index < done.count { return setText(done[index], bodyweight: exercise.bodyweight) }
                let planned = LiveStrengthNextSet(
                    blockId: block.id, exerciseId: exercise.id, setIndex: index, round: index + 1,
                    reps: exercise.reps, seconds: exercise.seconds, weight: LiveStrengthQueue.plannedWeight(exercise, in: session)
                )
                return target(planned, exercise: exercise)
            }
            let last = reference.flatMap { exercise in
                (exercise.last.indices.contains(index) ? exercise.last[index] : exercise.last.last).map { setText($0, bodyweight: exercise.bodyweight) }
            }
            let state: LiveStrengthRowState = counts.allSatisfy { $0 > index } ? .done : index == current ? .next : .pending
            return LiveStrengthRoundRow(number: index + 1, state: state, cells: cells, last: last)
        }
        return LiveStrengthRound(
            letter: letter, number: min(current + 1, block.rounds), exercises: exercises,
            markers: exercises.map { labels[$0.id]?.marker ?? "" }, rows: rows
        )
    }

    static func markers(_ plan: LiveStrengthPlan) -> [String: (number: Int, marker: String, superset: String?)] {
        var result: [String: (number: Int, marker: String, superset: String?)] = [:]
        var number = 0
        var supersets = 0
        for block in plan.blocks {
            let letter = block.isSuperset ? String(UnicodeScalar(UInt8(65 + supersets % 26))) : nil
            if block.isSuperset { supersets += 1 }
            for (position, exercise) in block.exercises.enumerated() {
                number += 1
                result[exercise.id] = (number, letter.map { $0 + String(position + 1) } ?? String(number), letter)
            }
        }
        return result
    }

    static func rows(_ exercise: LiveStrengthExercise, rounds: Int, next: LiveStrengthNextSet, session: LiveStrengthSession) -> [LiveStrengthSetRow] {
        let done = session.done[exercise.id] ?? []
        let original = LiveStrengthNextSet(
            blockId: next.blockId, exerciseId: exercise.id, setIndex: 0, round: 1, reps: exercise.reps, seconds: exercise.seconds, weight: exercise.weight
        )
        return (0..<max(rounds, done.count)).map { index in
            let last = exercise.last.indices.contains(index) ? exercise.last[index] : exercise.last.last
            let lastText = last.map { setText($0, bodyweight: exercise.bodyweight) }
            guard index < done.count else {
                return LiveStrengthSetRow(
                    number: index + 1, state: index == done.count ? .next : .pending, done: nil, doneText: nil,
                    repsBelow: false, weightChanged: false, plan: target(next, exercise: exercise), last: lastText
                )
            }
            let result = done[index]
            return LiveStrengthSetRow(
                number: index + 1, state: .done, done: result, doneText: setText(result, bodyweight: exercise.bodyweight),
                repsBelow: (result.reps ?? 0) < (exercise.reps ?? 0) || (result.seconds ?? 0) < (exercise.kind == .timed ? exercise.seconds ?? 0 : 0),
                weightChanged: (result.weight ?? 0) != (exercise.weight ?? 0),
                plan: target(original, exercise: exercise), last: lastText
            )
        }
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

    public static func setText(_ result: LiveStrengthSetResult, bodyweight: Bool) -> String {
        if let seconds = result.seconds, result.reps == nil { return String(seconds) + C.secondsSuffix }
        if result.reps == nil, let weight = result.weight, weight > 0 { return kilograms(weight) + C.kilogramSuffix }
        let reps = result.reps.map(String.init) ?? C.missingReps
        guard let weight = result.weight, weight > 0 else { return bodyweight ? reps + C.bodyweightSeparator + C.bodyweight : reps }
        return reps + C.times + kilograms(weight)
    }

    static func kilograms(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "pt_BR")))
    }

    public static func shortName(_ name: String) -> String {
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
