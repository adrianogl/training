import Foundation

public enum LiveStrengthSource: String, Codable, Sendable, Equatable {
    case mfit, trainer
}

public enum LiveStrengthSetKind: String, Codable, Sendable, Equatable {
    case reps, timed
}

public struct LiveStrengthSetResult: Codable, Sendable, Equatable {
    public var reps: Int?
    public var seconds: Int?
    public var weight: Double?
    public var start: Date?
    public var durationSeconds: Double?

    public init(reps: Int? = nil, seconds: Int? = nil, weight: Double? = nil, start: Date? = nil, durationSeconds: Double? = nil) {
        self.reps = reps
        self.seconds = seconds
        self.weight = weight
        self.start = start
        self.durationSeconds = durationSeconds
    }
}

public struct LiveStrengthExercise: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var category: String?
    public var exerciseKey: String?
    public var loadKey: String
    public var kind: LiveStrengthSetKind
    public var reps: Int?
    public var seconds: Int?
    public var weight: Double?
    public var bodyweight: Bool
    public var perSide: Bool
    public var last: [LiveStrengthSetResult]

    public init(
        id: String, name: String, category: String?, exerciseKey: String?, loadKey: String, kind: LiveStrengthSetKind,
        reps: Int?, seconds: Int?, weight: Double?, bodyweight: Bool, perSide: Bool, last: [LiveStrengthSetResult] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.exerciseKey = exerciseKey
        self.loadKey = loadKey
        self.kind = kind
        self.reps = reps
        self.seconds = seconds
        self.weight = weight
        self.bodyweight = bodyweight
        self.perSide = perSide
        self.last = last
    }
}

public struct LiveStrengthBlock: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var exercises: [LiveStrengthExercise]
    public var rounds: Int
    public var restSeconds: Int

    public init(id: String, exercises: [LiveStrengthExercise], rounds: Int, restSeconds: Int) {
        self.id = id
        self.exercises = exercises
        self.rounds = rounds
        self.restSeconds = restSeconds
    }

    public var isSuperset: Bool { exercises.count > 1 }
}

public struct LiveStrengthPlan: Codable, Sendable, Equatable {
    public var day: String
    public var title: String
    public var source: LiveStrengthSource
    public var blocks: [LiveStrengthBlock]
    public var sourceId: Int64?

    public init(day: String, title: String, source: LiveStrengthSource, blocks: [LiveStrengthBlock], sourceId: Int64? = nil) {
        self.day = day
        self.title = title
        self.source = source
        self.blocks = blocks
        self.sourceId = sourceId
    }

    public var totalSets: Int {
        blocks.reduce(0) { $0 + $1.rounds * $1.exercises.count }
    }

    public func block(containing exerciseId: String) -> LiveStrengthBlock? {
        blocks.first { $0.exercises.contains { $0.id == exerciseId } }
    }

    public func exercise(_ exerciseId: String) -> LiveStrengthExercise? {
        blocks.lazy.flatMap(\.exercises).first { $0.id == exerciseId }
    }
}

public struct LiveStrengthMFITReader: Sendable {
    public var loadKey: @Sendable (String) -> String
    public var target: @Sendable (String) -> (reps: Int?, seconds: Int?)

    public init(loadKey: @escaping @Sendable (String) -> String, target: @escaping @Sendable (String) -> (reps: Int?, seconds: Int?)) {
        self.loadKey = loadKey
        self.target = target
    }
}
