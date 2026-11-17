import TrainingCore

public struct ClaudeStrengthResponse: Codable, Sendable, Equatable {
    public var version: Int
    public var author: String?
    public var summary: String?
    public var workouts: [ClaudeStrengthDay]

    enum CodingKeys: String, CodingKey {
        case version = "versao", author = "autor", summary = "resumo", workouts = "treinos"
    }
}

public struct ClaudeStrengthDay: Codable, Sendable, Equatable {
    public var day: String
    public var focus: TrainerStrengthGroup?
    public var minutes: Int?
    public var place: StrengthPlace?
    public var why: String?
    public var exercises: [ClaudeStrengthExercise]

    enum CodingKeys: String, CodingKey {
        case day = "dia", focus = "foco", minutes = "minutos", place = "local", why = "porque", exercises = "exercicios"
    }
}

public struct ClaudeStrengthExercise: Codable, Sendable, Equatable {
    public var id: String
    public var sets: Int
    public var reps: Int?
    public var seconds: Int?
    public var rest: Int?
    public var kilograms: Double?

    enum CodingKeys: String, CodingKey {
        case id, sets = "series", reps, seconds = "segundos", rest = "descanso", kilograms = "kg"
    }
}

public enum ClaudeStrengthParseError: Error, Equatable {
    case invalid
    case unsupportedVersion(Int)
}

public enum ClaudeIssue: Sendable, Equatable, Hashable {
    case invalidDate, pastDay, outOfPeriod, mfitDay, notTrainerDay
    case unknownExercise(String), wrongPlace(String), painRegion(String), doseOutOfRange(String)
    case noExercises, tooManyExercises, heavyLegsBeforeQuality, nearRace
    case durationOff(estimated: Int, planned: Int), loadJump(String)
}

public struct ClaudeValidationContext: Sendable {
    public var today: Day
    public var first: Day
    public var last: Day
    public var trainerSessions: [TrainerStrengthSession]
    public var mfitWeekdays: Set<Int>
    public var runKinds: [Day: TrainerDayKind]
    public var raceDay: Day?
    public var pain: Set<BodyRegion>
    public var lastLoads: [String: Double]

    public init(
        today: Day, first: Day, last: Day, trainerSessions: [TrainerStrengthSession], mfitWeekdays: Set<Int>,
        runKinds: [Day: TrainerDayKind], raceDay: Day?, pain: Set<BodyRegion>, lastLoads: [String: Double]
    ) {
        self.today = today
        self.first = first
        self.last = last
        self.trainerSessions = trainerSessions
        self.mfitWeekdays = mfitWeekdays
        self.runKinds = runKinds
        self.raceDay = raceDay
        self.pain = pain
        self.lastLoads = lastLoads
    }
}

public struct ClaudeDayResult: Sendable, Equatable {
    public var rawDay: String
    public var day: Day?
    public var why: String?
    public var workout: GeneratedStrengthWorkout?
    public var errors: [ClaudeIssue]
    public var warnings: [ClaudeIssue]

    public var isValid: Bool { errors.isEmpty && workout != nil }

    public init(rawDay: String, day: Day?, why: String?, workout: GeneratedStrengthWorkout?, errors: [ClaudeIssue], warnings: [ClaudeIssue]) {
        self.rawDay = rawDay
        self.day = day
        self.why = why
        self.workout = workout
        self.errors = errors
        self.warnings = warnings
    }
}
