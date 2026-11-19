import Foundation
import GarminAPI
import Insights
import TrainingCore

enum TrainerSendBuilder {
    private typealias C = TrainerSendConstants

    static func runSteps(_ workout: TrainerWorkout) -> [PlannedRunStep] {
        guard !workout.steps.isEmpty else {
            return [.interval(meters: workout.totalMeters, fastest: workout.paceLow, slowest: workout.paceHigh)]
        }
        return workout.steps.flatMap { step -> [PlannedRunStep] in
            switch step.kind {
            case .warmup: return [.warmup(meters: step.meters)]
            case .cooldown: return [.cooldown(meters: step.meters)]
            case .recovery: return [.recovery(meters: step.meters)]
            case .work, .steady:
                let interval = PlannedRunStep.interval(meters: step.meters, fastest: step.paceLow ?? workout.paceLow, slowest: step.paceHigh ?? workout.paceHigh)
                let rest = (step.restSeconds ?? 0) > 0 ? [PlannedRunStep.rest(seconds: step.restSeconds ?? 0)] : []
                return step.repeats > 1 ? [.repeated(times: step.repeats, steps: [interval] + rest)] : [interval] + rest
            }
        }
    }

    static func strengthExercises(_ exercises: [GeneratedExercise]) -> [PlannedStrengthExercise] {
        exercises.map { exercise in
            PlannedStrengthExercise(
                description: exercise.name + (exercise.perSide ? C.perSideSuffix : ""), category: exercise.category,
                exerciseName: exercise.exerciseName ?? StrengthCatalog.exercise(exercise.exerciseId)?.exerciseName, sets: exercise.sets, reps: exercise.reps, seconds: exercise.seconds,
                restSeconds: exercise.restSeconds, weight: exercise.weight
            )
        }
    }

    static func runItem(_ workout: TrainerWorkout) -> TrainerSendItem? {
        guard !C.skippedKinds.contains(workout.kind),
              let payload = try? GarminPlannedPayload.running(name: C.namePrefix + workout.title, steps: runSteps(workout)) else { return nil }
        return TrainerSendItem(key: C.runKeyPrefix + workout.day.iso, day: workout.day, kind: .run, title: workout.title, payload: payload, runSteps: runSteps(workout))
    }

    static func strengthItem(_ workout: GeneratedStrengthWorkout, sessionId: UUID, day: Day) -> TrainerSendItem? {
        let title = TrainerStrengthText.focusName(workout.group)
        guard !workout.exercises.isEmpty,
              let payload = try? GarminPlannedPayload.strength(name: C.namePrefix + title, exercises: strengthExercises(workout.exercises)) else { return nil }
        return TrainerSendItem(
            key: C.strengthKeyPrefix + day.iso + "|" + sessionId.uuidString, day: day, kind: .strength, title: title, payload: payload,
            strengthSeconds: strengthSeconds(workout.exercises)
        )
    }

    static func strengthSeconds(_ exercises: [GeneratedExercise]) -> Double {
        exercises.reduce(0) { total, exercise in
            let work = Double(exercise.seconds ?? (exercise.reps ?? 0) * C.secondsPerRep)
            return total + Double(exercise.sets) * (work + Double(exercise.restSeconds))
        }
    }

    static func status(_ item: TrainerSendItem, records: [String: TrainerSentRecord]) -> TrainerSendStatus {
        guard let record = records[item.key] else { return .new }
        return record.signature == item.signature ? .current : .changed
    }

    static func stale(records: [String: TrainerSentRecord], current: Set<String>, kinds: Set<TrainerSendKind>, from first: Day, through last: Day) -> [TrainerSentRecord] {
        records
            .filter { key, record in
                guard !current.contains(key), kinds.contains(record.kind), let day = Day(iso: record.day) else { return false }
                return day >= first && day <= last
            }
            .map(\.value)
            .sorted { $0.day < $1.day }
    }
}
