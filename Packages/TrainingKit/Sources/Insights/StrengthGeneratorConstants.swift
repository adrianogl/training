import TrainingCore

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
    static let loadedEquipment: Set<StrengthEquipment> = [.barbell, .machine, .cable, .dumbbell, .kettlebell, .medicineBall]
    static let mobilityOrder: [MovementPattern] = [.mobilityHip, .mobilityAnkle, .mobilityThoracic]
    static let patternOrder: [TrainerStrengthGroup: [MovementPattern]] = [
        .lower: [.squat, .hinge, .singleLeg, .calf, .hipStability, .plyo, .lateralCore],
        .upper: [.horizontalPush, .horizontalPull, .verticalPush, .verticalPull, .hinge, .antiRotation, .lateralCore],
        .fullBody: [.squat, .horizontalPull, .hinge, .horizontalPush, .singleLeg, .antiExtension, .calf, .verticalPush, .lateralCore, .antiRotation],
        .mobility: mobilityOrder,
        .core: [.mobilityHip, .antiRotation, .mobilityAnkle, .antiExtension, .hipStability, .mobilityThoracic, .lateralCore, .singleLeg, .hinge, .calf],
    ]
    static let performanceOrder: [TrainerStrengthGroup: [MovementPattern]] = [
        .lower: [.singleLeg, .plyo, .calf, .hipStability, .squat, .hinge, .lateralCore],
        .fullBody: [.singleLeg, .hinge, .plyo, .calf, .squat, .horizontalPull, .hipStability, .antiExtension, .horizontalPush, .lateralCore],
    ]
    static let maintenanceExcluded: Set<MovementPattern> = [.plyo]
    static let staticMobilityWord = "STRETCH"
    static let equipmentPreference: [StrengthEquipment] = [.barbell, .machine, .cable, .dumbbell, .kettlebell, .band, .bodyweight, .medicineBall, .swissBall, .suspension]
    static let comboWords: Set<Substring> = ["TO", "AND", "CIRCUIT", "MATRIX", "COMBO"]
    static let simpleTokenLimit = 4
    static let maxExercises = 8
    static let maxCoreExercises = 12
    static let weightedPrefix = "WEIGHTED_"
    static let advancedWords = ["HIGH_PULL", "BURPEE", "SIFF", "DEFICIT", "JUMP_SHRUG", "THRUSTER", "THRUSTERS", "MAN_MAKERS", "PISTOL", "DEPTH_JUMP", "SQUAT_CLEAN", "ZERCHER", "BOARD", "TRIPLE_STOP", "PARTIAL", "CHEATING", "KIPPING", "QUARTER"]
    static let patternEquipmentPreference: [MovementPattern: [StrengthEquipment]] = [
        .verticalPull: [.cable, .machine, .band, .bodyweight, .dumbbell, .barbell, .kettlebell, .suspension, .medicineBall, .swissBall],
    ]
    static let bodyweightFirstPatterns: Set<MovementPattern> = [.plyo, .antiExtension, .mobilityHip, .mobilityAnkle, .mobilityThoracic]
    static let rotationEpoch = Day(year: 2026, month: 1, day: 5)
    static let rotationDays = 28
    static let alternativesCount = 3
}
