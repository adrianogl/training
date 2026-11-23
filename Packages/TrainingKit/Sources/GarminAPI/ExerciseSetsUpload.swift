import Foundation

public enum ExerciseSetsUpload {
    private typealias C = ExerciseSetsUploadConstants

    public static func upload(client: GarminAccountClient, activityId: Int64, sets: [ExerciseSetUpload]) async throws {
        _ = try await client.put(String(format: GarminAccountEndpoints.exerciseSetsPathFormat, activityId), body: payload(activityId: activityId, sets: sets))
    }

    static func payload(activityId: Int64, sets: [ExerciseSetUpload]) throws -> Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = C.startTimeZone
        formatter.dateFormat = C.startTimeFormat
        let body: [String: Any] = [
            "activityId": activityId,
            "exerciseSets": sets.map { set(_: $0, formatter: formatter) },
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    private static func set(_ set: ExerciseSetUpload, formatter: DateFormatter) -> [String: Any] {
        let exercises: [[String: Any]] = set.category.map { category in
            [["category": category, "name": set.exerciseKey ?? NSNull(), "probability": C.probability]]
        } ?? []
        return [
            "setType": set.kind.rawValue,
            "startTime": formatter.string(from: set.start),
            "duration": set.durationSeconds,
            "repetitionCount": set.reps ?? NSNull(),
            "weight": set.weightKg.map { $0 * C.gramsPerKilogram } ?? NSNull(),
            "exercises": exercises,
        ]
    }
}
