import TrainingCore

public enum MuscleGroup: String, CaseIterable, Sendable, Codable {
    case chest, shoulders, biceps, triceps, forearms, abs, obliques, traps, lats, lowerBack, glutes, quads, hamstrings, adductors, calves
}

public enum StrengthScale: Sendable {
    case session
    case week
}

public struct StrengthWeekDay: Sendable, Equatable {
    public var day: Day
    public var run: TrainerDayKind?
    public var legs: Bool

    public init(day: Day, run: TrainerDayKind?, legs: Bool) {
        self.day = day
        self.run = run
        self.legs = legs
    }
}
