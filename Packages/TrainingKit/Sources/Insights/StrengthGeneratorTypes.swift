public struct StrengthLoadRecord: Codable, Sendable, Equatable {
    public var weight: Double
    public var completedAllSets: Bool

    public init(weight: Double, completedAllSets: Bool) {
        self.weight = weight
        self.completedAllSets = completedAllSets
    }
}

public struct StrengthContext: Sendable, Equatable {
    public var runKind: TrainerDayKind?
    public var isRecoveryWeek: Bool
    public var daysToRace: Int?
    public var readiness: Int?
    public var pain: Set<BodyRegion>
    public var coveredPatterns: Set<MovementPattern>
    public var loads: [String: StrengthLoadRecord]
    public var swaps: [String: String]
    public var keepOriginal: Bool

    public init(
        runKind: TrainerDayKind? = nil, isRecoveryWeek: Bool = false, daysToRace: Int? = nil, readiness: Int? = nil,
        pain: Set<BodyRegion> = [], coveredPatterns: Set<MovementPattern> = [], loads: [String: StrengthLoadRecord] = [:],
        swaps: [String: String] = [:], keepOriginal: Bool = false
    ) {
        self.runKind = runKind
        self.isRecoveryWeek = isRecoveryWeek
        self.daysToRace = daysToRace
        self.readiness = readiness
        self.pain = pain
        self.coveredPatterns = coveredPatterns
        self.loads = loads
        self.swaps = swaps
        self.keepOriginal = keepOriginal
    }
}

public enum StrengthAdjustment: Codable, Sendable, Equatable, Hashable {
    case qualityDay(original: TrainerStrengthGroup)
    case recoveryWeek
    case raceWeek
    case raceRest
    case lowReadiness(score: Int)
    case pain(Set<BodyRegion>)
}

public struct GeneratedExercise: Codable, Sendable, Equatable, Identifiable {
    public var exerciseId: String
    public var name: String
    public var category: String
    public var exerciseName: String?
    public var sets: Int
    public var reps: Int?
    public var seconds: Int?
    public var restSeconds: Int
    public var weight: Double?
    public var perSide: Bool
    public var replacedName: String?
    public var replacedId: String?

    public var id: String { exerciseId }

    var workSeconds: Double {
        let single = Double(seconds ?? (reps ?? 0) * StrengthGeneratorConstants.secondsPerRep)
        return perSide ? single * 2 : single
    }

    var estimatedSeconds: Double {
        Double(sets) * (workSeconds + Double(restSeconds))
    }
}

public struct GeneratedStrengthWorkout: Codable, Sendable, Equatable {
    public var weekday: Int
    public var group: TrainerStrengthGroup
    public var intensity: TrainerStrengthIntensity
    public var minutes: Int
    public var place: StrengthPlace
    public var exercises: [GeneratedExercise]
    public var adjustments: [StrengthAdjustment]

    public var estimatedMinutes: Double {
        exercises.reduce(0) { $0 + $1.estimatedSeconds } / 60
    }

    public var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }
}

struct StrengthPrescription {
    let sets: Int
    let reps: Int?
    let seconds: Int?
    let rest: Int
}
