import Foundation
import GarminAPI
import Insights
import TrainingCore

enum TrainerSendBuilder {
    private typealias C = TrainerSendConstants

    static func runSteps(_ workout: TrainerWorkout, thresholdHeartRate: Int? = nil, maxHeartRate: Int? = nil) -> [PlannedRunStep] {
        let bands = TrainerZones.bands(thresholdHeartRate: thresholdHeartRate, paces: nil, maxHeartRate: maxHeartRate)
        func heartRate(_ step: TrainerStep) -> ClosedRange<Int>? {
            guard let zone = TrainerZones.zone(step, in: workout),
                  let band = bands.first(where: { $0.zone == zone }), let low = band.heartRateLow, let high = band.heartRateHigh, low <= high else { return nil }
            return low...high
        }
        guard !workout.steps.isEmpty else {
            return [.interval(meters: workout.totalMeters, fastest: workout.paceLow, slowest: workout.paceHigh)]
        }
        let steps = workout.steps
        var result: [PlannedRunStep] = []
        var index = 0
        while index < steps.count {
            let step = steps[index]
            switch step.kind {
            case .warmup:
                result.append(.warmup(meters: step.meters, fastest: step.paceLow, slowest: step.paceHigh, heartRate: heartRate(step)))
            case .cooldown:
                result.append(.cooldown(meters: step.meters, fastest: step.paceLow, slowest: step.paceHigh, heartRate: heartRate(step)))
            case .recovery:
                result.append(recovery(step))
            case .work, .steady:
                let interval = PlannedRunStep.interval(
                    meters: step.meters, fastest: step.paceLow ?? workout.paceLow, slowest: step.paceHigh ?? workout.paceHigh, heartRate: heartRate(step)
                )
                let next = index + 1 < steps.count ? steps[index + 1] : nil
                if step.repeats > 1, let next, next.kind == .recovery, next.repeats == step.repeats - 1 {
                    result += series(step.repeats, interval: interval, recovery: recovery(next))
                    index += 2
                    index += coveredRest(steps, at: index, by: next.restSeconds) ? 1 : 0
                    continue
                }
                if step.repeats > 1, let seconds = step.restSeconds, seconds > 0 {
                    result += series(step.repeats, interval: interval, recovery: .rest(seconds: seconds))
                    index += 1
                    index += coveredRest(steps, at: index, by: seconds) ? 1 : 0
                    continue
                } else if step.repeats > 1 {
                    result.append(.repeated(times: step.repeats, steps: [interval]))
                } else {
                    result += [interval] + ((step.restSeconds ?? 0) > 0 ? [.rest(seconds: step.restSeconds ?? 0)] : [])
                }
            }
            index += 1
        }
        return result
    }

    private static func coveredRest(_ steps: [TrainerStep], at index: Int, by seconds: Double?) -> Bool {
        guard let seconds, index < steps.count else { return false }
        let next = steps[index]
        guard next.kind == .recovery, next.repeats <= 1, let rest = next.restSeconds, rest > 0 else { return false }
        return rest <= seconds
    }

    private static func series(_ repeats: Int, interval: PlannedRunStep, recovery: PlannedRunStep) -> [PlannedRunStep] {
        [.repeated(times: repeats, steps: [interval, recovery])]
    }

    private static func recovery(_ step: TrainerStep) -> PlannedRunStep {
        if let seconds = step.restSeconds, seconds > 0 { return .rest(seconds: seconds) }
        return .recovery(meters: step.meters)
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

    static func runItem(_ workout: TrainerWorkout, thresholdHeartRate: Int? = nil, maxHeartRate: Int? = nil) -> TrainerSendItem? {
        let steps = runSteps(workout, thresholdHeartRate: thresholdHeartRate, maxHeartRate: maxHeartRate)
        guard !C.skippedKinds.contains(workout.kind),
              let payload = try? GarminPlannedPayload.running(name: workout.title, steps: steps) else { return nil }
        return TrainerSendItem(key: C.runKeyPrefix + workout.day.iso, day: workout.day, kind: .run, title: workout.title, payload: payload, runSteps: steps)
    }

    static func runItem(
        _ workout: TrainerWorkout, entries: DayAdjustEntries?, thresholdHeartRate: Int? = nil, maxHeartRate: Int? = nil
    ) -> TrainerSendItem? {
        guard let plain = runItem(workout, thresholdHeartRate: thresholdHeartRate, maxHeartRate: maxHeartRate) else { return nil }
        guard let entries, entries.day == workout.day else { return plain }
        let result = TrainerDayAdjust.adjust(workout, entries: entries)
        var item = plain
        if case let .adjusted(change) = result,
           let adjusted = runItem(change.workout, thresholdHeartRate: thresholdHeartRate, maxHeartRate: maxHeartRate) {
            item = adjusted
            item.dayAdjustSeconds = change.seconds
        }
        item.dayAdjust = entries
        item.heatShare = TrainerDayAdjust.includedHeatShare(result, entries: entries)
        item.planSignature = plain.signature
        return item
    }

    static func strengthItem(_ workout: GeneratedStrengthWorkout, sessionId: UUID, day: Day) -> TrainerSendItem? {
        let title = TrainerStrengthText.focusName(workout.group)
        guard !workout.exercises.isEmpty,
              let payload = try? GarminPlannedPayload.strength(name: title, exercises: strengthExercises(workout.exercises)) else { return nil }
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

    static func planRecords(_ records: [String: TrainerSentRecord], from first: Day) -> [(key: String, record: TrainerSentRecord)] {
        records
            .filter { key, record in
                (key.hasPrefix(C.runKeyPrefix) || key.hasPrefix(C.strengthKeyPrefix)) && (Day(iso: record.day).map { $0 >= first } ?? false)
            }
            .map { (key: $0.key, record: $0.value) }
            .sorted { $0.record.day < $1.record.day }
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
