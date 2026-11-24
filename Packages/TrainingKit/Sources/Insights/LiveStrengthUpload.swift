import Foundation
import GarminAPI

public enum LiveStrengthUpload {
    private typealias C = LiveStrengthUploadConstants

    public static func sets(_ session: LiveStrengthSession) -> [ExerciseSetUpload] {
        let blockOf = Dictionary(session.plan.blocks.flatMap { block in block.exercises.map { ($0.id, block) } }, uniquingKeysWith: { first, _ in first })
        let collected = session.plan.blocks.flatMap(\.exercises).flatMap { exercise in
            withInheritedReps(session.done[exercise.id] ?? [], kind: exercise.kind).compactMap { result -> (LiveStrengthExercise, LiveStrengthSetResult, Date)? in
                result.start.map { (exercise, result, $0) }
            }
        }.sorted { $0.2 < $1.2 }
        let done = splitSupersetRounds(collected, blockOf: blockOf)
        var uploads: [ExerciseSetUpload] = []
        var previousEnd: Date?
        for (exercise, result, start) in done {
            if let previousEnd, start.timeIntervalSince(previousEnd) >= C.minimumRest {
                uploads.append(.rest(start: previousEnd, durationSeconds: start.timeIntervalSince(previousEnd)))
            }
            let duration = result.durationSeconds ?? 0
            uploads.append(.active(
                category: exercise.category ?? C.unknownCategory,
                exerciseKey: exerciseName(exercise.exerciseKey),
                reps: result.reps,
                weightKg: (result.weight ?? 0) > 0 ? result.weight : nil,
                start: start,
                durationSeconds: duration
            ))
            previousEnd = start.addingTimeInterval(duration)
        }
        return uploads
    }

    public static func match(_ activities: [ActivityDTO], startedAt: Date, timeZone: TimeZone = .current) -> ActivityDTO? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = C.localFormat
        return activities
            .filter { $0.typeKey == C.strengthType }
            .compactMap { activity -> (ActivityDTO, TimeInterval)? in
                guard let text = activity.startTimeLocal, let start = formatter.date(from: text) else { return nil }
                let gap = abs(start.timeIntervalSince(startedAt))
                return gap <= C.startTolerance ? (activity, gap) : nil
            }
            .min { $0.1 < $1.1 }?.0
    }

    static func withInheritedReps(_ results: [LiveStrengthSetResult], kind: LiveStrengthSetKind) -> [LiveStrengthSetResult] {
        guard kind == .reps else { return results }
        var last: Int?
        return results.map { result in
            var filled = result
            if let reps = result.reps { last = reps } else { filled.reps = last }
            return filled
        }
    }

    static func splitSupersetRounds(
        _ sets: [(LiveStrengthExercise, LiveStrengthSetResult, Date)], blockOf: [String: LiveStrengthBlock]
    ) -> [(LiveStrengthExercise, LiveStrengthSetResult, Date)] {
        var result = sets
        for index in result.indices.dropFirst() {
            let (exercise, set, _) = result[index]
            let (previous, previousSet, previousStart) = result[index - 1]
            guard let block = blockOf[exercise.id], block.isSuperset, blockOf[previous.id]?.id == block.id, previous.id != exercise.id,
                  let duration = set.durationSeconds, duration < C.minimumSupersetSetSeconds,
                  let previousDuration = previousSet.durationSeconds else { continue }
            let half = (duration + previousDuration) / 2
            var first = previousSet
            first.durationSeconds = half
            var second = set
            second.durationSeconds = half
            let secondStart = previousStart.addingTimeInterval(half)
            second.start = secondStart
            result[index - 1] = (previous, first, previousStart)
            result[index] = (exercise, second, secondStart)
        }
        return result
    }

    static func exerciseName(_ key: String?) -> String? {
        guard let key else { return nil }
        return key.split(separator: "/").last.map(String.init) ?? key
    }
}
