import Foundation
import GarminAPI

public enum LiveStrengthUpload {
    private typealias C = LiveStrengthUploadConstants

    public static func sets(_ session: LiveStrengthSession) -> [ExerciseSetUpload] {
        let done = session.plan.blocks.flatMap(\.exercises).flatMap { exercise in
            (session.done[exercise.id] ?? []).compactMap { result -> (LiveStrengthExercise, LiveStrengthSetResult, Date)? in
                result.start.map { (exercise, result, $0) }
            }
        }.sorted { $0.2 < $1.2 }
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

    static func exerciseName(_ key: String?) -> String? {
        guard let key else { return nil }
        return key.split(separator: "/").last.map(String.init) ?? key
    }
}
