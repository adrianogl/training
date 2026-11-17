enum StrengthGeneratorConstants {
    static let secondsPerRep = 3
    static let toleranceMinutes = 5.0
    static let maxExtraSets = 4
    static let lowReadiness = 50
    static let raceRestDays = 3
    static let raceWeekDays = 7
    static let raceWeekMinutes = 15
    static let lowReadinessMinutes = 20
    static let recoveryShare = 0.7
    static let progressionShare = 0.025
    static let minimumIncrease = 1.0
    static let qualityKinds: Set<TrainerDayKind> = [.threshold, .vo2max, .long, .race]
    static let legGroups: Set<TrainerStrengthGroup> = [.lower, .fullBody]
    static let mainPatterns: Set<MovementPattern> = [.squat, .hinge, .horizontalPush, .horizontalPull, .verticalPush, .verticalPull]
    static let mainEquipment: Set<StrengthEquipment> = [.barbell, .machine]
    static let coreLikePatterns: Set<MovementPattern> = [.antiExtension, .antiRotation, .lateralCore, .hipStability]
    static let loadedEquipment: Set<StrengthEquipment> = [.barbell, .machine, .cable, .dumbbell]
    static let mobilityOrder: [MovementPattern] = [.mobilityHip, .mobilityAnkle, .mobilityThoracic]
    static let patternOrder: [TrainerStrengthGroup: [MovementPattern]] = [
        .lower: [.squat, .hinge, .singleLeg, .calf, .hipStability, .plyo, .lateralCore],
        .upper: [.horizontalPush, .horizontalPull, .verticalPush, .verticalPull, .hinge, .antiRotation, .lateralCore],
        .fullBody: [.squat, .horizontalPull, .hinge, .horizontalPush, .singleLeg, .antiExtension, .calf, .verticalPush, .lateralCore, .antiRotation],
        .core: [.mobilityHip, .antiRotation, .mobilityAnkle, .antiExtension, .hipStability, .mobilityThoracic, .lateralCore, .singleLeg, .hinge, .calf],
    ]
    static let equipmentPreference: [StrengthEquipment] = [.barbell, .machine, .cable, .dumbbell, .band, .bodyweight]
}
