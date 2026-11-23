import Foundation

public enum LiveStrengthReport {
    public static func summarize(_ session: LiveStrengthSession, durationSeconds: Double, averageHeartRate: Int?) -> LiveStrengthSummary {
        let exercises = session.plan.blocks.flatMap { block in block.exercises.map { (block, $0) } }
        let total = exercises.reduce(0) { $0 + volume(session.done[$1.1.id] ?? [], perSide: $1.1.perSide) }
        let comparable = exercises.map(\.1).filter { !$0.last.isEmpty && !(session.done[$0.id] ?? []).isEmpty }
        let previousTotal = comparable.isEmpty ? nil : comparable.reduce(0) { $0 + volume($1.last, perSide: $1.perSide) }
        let comparableTotal = comparable.reduce(0) { $0 + volume(session.done[$1.id] ?? [], perSide: $1.perSide) }
        let summaries = exercises.map { block, exercise in
            LiveStrengthExerciseSummary(
                id: exercise.id,
                name: exercise.name,
                sets: session.done[exercise.id] ?? [],
                change: change(exercise, rounds: block.rounds, done: session.done[exercise.id] ?? [])
            )
        }
        return LiveStrengthSummary(
            volume: total,
            previousVolume: previousTotal,
            volumeChange: previousTotal.flatMap { $0 > 0 ? comparableTotal / $0 - 1 : nil },
            durationSeconds: durationSeconds,
            averageHeartRate: averageHeartRate,
            setsDone: LiveStrengthQueue.setsDone(session),
            setsPlanned: session.plan.totalSets,
            offPlan: exercises.reduce(0) { $0 + offPlan($1.1, done: session.done[$1.1.id] ?? []) },
            exercises: summaries,
            skipped: summaries.filter { $0.change == .skipped }.map(\.name),
            loads: loads(session)
        )
    }

    public static func realLoads(_ session: LiveStrengthSession) -> [LiveStrengthRealLoad] {
        session.plan.blocks.flatMap(\.exercises).compactMap { exercise in
            let loads = (session.done[exercise.id] ?? []).compactMap(\.weight).filter { $0 > 0 }
            return loads.isEmpty ? nil : LiveStrengthRealLoad(name: exercise.name, loadKey: exercise.loadKey, loads: loads)
        }
    }

    public static func nextLoads(_ session: LiveStrengthSession) -> [LiveStrengthNextLoad] {
        let records = loads(session)
        return session.plan.blocks.flatMap(\.exercises).compactMap { exercise in
            guard let record = records[exercise.loadKey], let next = StrengthProgression.next(record) else { return nil }
            return LiveStrengthNextLoad(name: exercise.name, loadKey: exercise.loadKey, weight: record.weight, next: next)
        }
    }

    public static func loads(_ session: LiveStrengthSession) -> [String: StrengthLoadRecord] {
        var records: [String: StrengthLoadRecord] = [:]
        for block in session.plan.blocks {
            for exercise in block.exercises {
                let done = session.done[exercise.id] ?? []
                guard let weight = done.last(where: { $0.weight != nil })?.weight, weight > 0 else { continue }
                let complete = done.count >= block.rounds && offPlanShort(exercise, done: done) == 0
                records[exercise.loadKey] = StrengthLoadRecord(weight: weight, completedAllSets: complete, day: session.plan.day)
            }
        }
        return records
    }

    static func volume(_ sets: [LiveStrengthSetResult], perSide: Bool) -> Double {
        let sides = perSide ? 2.0 : 1.0
        return sets.reduce(0) { $0 + Double($1.reps ?? 0) * ($1.weight ?? 0) * sides }
    }

    static func change(_ exercise: LiveStrengthExercise, rounds: Int, done: [LiveStrengthSetResult]) -> LiveStrengthChange {
        if done.isEmpty { return .skipped }
        if let planned = exercise.weight, let top = done.compactMap(\.weight).max(), top != planned {
            return top > planned ? .heavier(top - planned) : .lighter(planned - top)
        }
        if let target = exercise.reps {
            let missing = target * rounds - done.reduce(0) { $0 + ($1.reps ?? target) }
            if missing > 0 { return .fewerReps(missing) }
        }
        return .asPlanned
    }

    static func offPlan(_ exercise: LiveStrengthExercise, done: [LiveStrengthSetResult]) -> Int {
        switch exercise.kind {
        case .reps:
            guard let target = exercise.reps else { return 0 }
            return done.filter { $0.reps.map { $0 != target } ?? false }.count
        case .timed:
            guard let target = exercise.seconds else { return 0 }
            return done.filter { $0.seconds.map { $0 != target } ?? false }.count
        }
    }

    static func offPlanShort(_ exercise: LiveStrengthExercise, done: [LiveStrengthSetResult]) -> Int {
        switch exercise.kind {
        case .reps:
            guard let target = exercise.reps else { return 0 }
            return done.filter { ($0.reps ?? target) < target }.count
        case .timed:
            guard let target = exercise.seconds else { return 0 }
            return done.filter { ($0.seconds ?? target) < target }.count
        }
    }
}
