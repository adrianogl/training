enum ClaudeStrengthConstants {
    static let version = 1
    static let sets = 1...6
    static let reps = 1...30
    static let seconds = 10...120
    static let rest = 0...240
    static let defaultRest = 60
    static let maxExercises = 12
    static let durationToleranceMinutes = 10.0
    static let loadJumpShare = 1.05
    static let raceRestDays = 0...3
    static let qualityKinds: Set<TrainerDayKind> = [.threshold, .vo2max, .long, .race]
    static let legPatterns: Set<MovementPattern> = [.squat, .hinge, .singleLeg, .plyo]
    static let loadedEquipment: Set<StrengthEquipment> = [.barbell, .machine, .dumbbell, .kettlebell]
    static let heavyLegExercises = 2
}
