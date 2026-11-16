import Foundation

public struct StrengthExercise: Sendable, Equatable, Codable {
    public var name: String
    public var detail: String?
    public var category: String?
    public var exerciseKey: String?
    public var reps: Int?
    public var seconds: Double?

    public init(name: String, detail: String?, category: String?, exerciseKey: String?, reps: Int?, seconds: Double?) {
        self.name = name
        self.detail = detail
        self.category = category
        self.exerciseKey = exerciseKey
        self.reps = reps
        self.seconds = seconds
    }
}

public struct StrengthBlock: Sendable, Equatable, Codable {
    public var exercises: [StrengthExercise]
    public var sets: Int
    public var restSeconds: Double?

    public init(exercises: [StrengthExercise], sets: Int, restSeconds: Double?) {
        self.exercises = exercises
        self.sets = sets
        self.restSeconds = restSeconds
    }
}

public struct StrengthWorkout: Sendable, Equatable, Codable, Identifiable {
    public var id: Int64
    public var day: String
    public var title: String
    public var blocks: [StrengthBlock]

    public init(id: Int64, day: String, title: String, blocks: [StrengthBlock]) {
        self.id = id
        self.day = day
        self.title = title
        self.blocks = blocks
    }

    public var totalSets: Int {
        blocks.reduce(0) { $0 + $1.sets * $1.exercises.count }
    }
}

public struct StrengthSet: Sendable, Equatable, Codable {
    public var stepIndex: Int?
    public var category: String?
    public var exerciseKey: String?
    public var reps: Int?
    public var seconds: Double?
    public var weight: Double?

    public init(stepIndex: Int?, category: String?, exerciseKey: String?, reps: Int?, seconds: Double?, weight: Double?) {
        self.stepIndex = stepIndex
        self.category = category
        self.exerciseKey = exerciseKey
        self.reps = reps
        self.seconds = seconds
        self.weight = weight
    }
}

struct ExerciseSetsDTO: Decodable {
    struct Exercise: Decodable {
        let category: String?
        let name: String?
    }

    struct Set: Decodable {
        let exercises: [Exercise]?
        let duration: Double?
        let repetitionCount: Int?
        let weight: Double?
        let setType: String?
        let wktStepIndex: Int?
    }

    let exerciseSets: [Set]?
}
