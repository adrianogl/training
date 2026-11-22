public indirect enum PlannedRunStep: Sendable, Equatable {
    case warmup(meters: Double, heartRate: ClosedRange<Int>? = nil)
    case interval(meters: Double, fastest: Double?, slowest: Double?, heartRate: ClosedRange<Int>? = nil)
    case recovery(meters: Double)
    case rest(seconds: Double)
    case cooldown(meters: Double)
    case repeated(times: Int, steps: [PlannedRunStep])
}

public struct PlannedStrengthExercise: Sendable, Equatable {
    public var description: String
    public var category: String
    public var exerciseName: String?
    public var sets: Int
    public var reps: Int?
    public var seconds: Int?
    public var restSeconds: Int
    public var weight: Double?

    public init(description: String, category: String, exerciseName: String?, sets: Int, reps: Int?, seconds: Int?, restSeconds: Int, weight: Double?) {
        self.description = description
        self.category = category
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.seconds = seconds
        self.restSeconds = restSeconds
        self.weight = weight
    }
}
