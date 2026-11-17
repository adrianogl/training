enum StrengthCatalogConstants {
    static let equipmentByPlace: [StrengthPlace: Set<StrengthEquipment>] = [
        .gym: [.barbell, .machine, .cable, .dumbbell, .band, .bodyweight],
        .home: [.dumbbell, .band, .bodyweight],
        .bodyweight: [.bodyweight],
    ]
    static let mobilityPatterns: Set<MovementPattern> = [.mobilityHip, .mobilityAnkle, .mobilityThoracic]
    static let patternByGarminCategory: [String: MovementPattern] = [
        "SQUAT": .squat, "DEADLIFT": .hinge, "HIP_RAISE": .hinge, "LEG_CURL": .hinge, "LUNGE": .singleLeg,
        "CALF_RAISE": .calf, "HIP_STABILITY": .hipStability, "PLYO": .plyo,
        "BENCH_PRESS": .horizontalPush, "PUSH_UP": .horizontalPush, "FLYE": .horizontalPush, "TRICEPS_EXTENSION": .horizontalPush,
        "ROW": .horizontalPull, "SHOULDER_STABILITY": .horizontalPull, "CURL": .verticalPull, "PULL_UP": .verticalPull,
        "SHOULDER_PRESS": .verticalPush, "PLANK": .antiExtension, "CORE": .antiExtension, "CRUNCH": .antiExtension,
        "SIT_UP": .antiExtension, "LEG_RAISE": .antiExtension, "CHOP": .antiRotation, "CARRY": .lateralCore,
        "WARM_UP": .mobilityHip, "HYPEREXTENSION": .hinge,
    ]
}
