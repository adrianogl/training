import Foundation

public enum ExerciseSetKind: String, Sendable, Equatable {
    case active = "ACTIVE"
    case rest = "REST"
}

public struct ExerciseSetUpload: Sendable, Equatable {
    public var kind: ExerciseSetKind
    public var category: String?
    public var exerciseKey: String?
    public var reps: Int?
    public var weightKg: Double?
    public var start: Date
    public var durationSeconds: Double

    public init(kind: ExerciseSetKind, category: String?, exerciseKey: String?, reps: Int?, weightKg: Double?, start: Date, durationSeconds: Double) {
        self.kind = kind
        self.category = category
        self.exerciseKey = exerciseKey
        self.reps = reps
        self.weightKg = weightKg
        self.start = start
        self.durationSeconds = durationSeconds
    }

    public static func active(category: String, exerciseKey: String?, reps: Int?, weightKg: Double?, start: Date, durationSeconds: Double) -> ExerciseSetUpload {
        ExerciseSetUpload(kind: .active, category: category, exerciseKey: exerciseKey, reps: reps, weightKg: weightKg, start: start, durationSeconds: durationSeconds)
    }

    public static func rest(start: Date, durationSeconds: Double) -> ExerciseSetUpload {
        ExerciseSetUpload(kind: .rest, category: nil, exerciseKey: nil, reps: nil, weightKg: nil, start: start, durationSeconds: durationSeconds)
    }
}
