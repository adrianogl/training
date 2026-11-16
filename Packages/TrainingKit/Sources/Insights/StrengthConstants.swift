enum StrengthConstants {
    static let secondaryWeight = 0.5
    static let sessionLevels: [Double] = [5, 10]
    static let weekLevels: [Double] = [7, 15]
    static let legDayShare = 0.5
    static let legMuscles: Set<MuscleGroup> = [.glutes, .quads, .hamstrings, .calves, .adductors]
    static let runsAfterLegs: Set<TrainerDayKind> = [.threshold, .vo2max, .long]
    static let primary: [String: [MuscleGroup]] = [
        "SQUAT": [.quads, .glutes], "LUNGE": [.quads, .glutes], "LEG_PRESS": [.quads, .glutes],
        "DEADLIFT": [.hamstrings, .glutes], "HIP_RAISE": [.glutes], "HIP_STABILITY": [.glutes],
        "HIP_SWING": [.glutes, .hamstrings], "LEG_CURL": [.hamstrings], "LEG_EXTENSION": [.quads], "HIP_ADDUCTION": [.adductors], "CALF_RAISE": [.calves],
        "BENCH_PRESS": [.chest], "PUSH_UP": [.chest], "CHEST_FLY": [.chest],
        "ROW": [.lats], "PULL_UP": [.lats], "REVERSE_FLY": [.shoulders], "LAT_PULLDOWN": [.lats],
        "SHOULDER_PRESS": [.shoulders], "LATERAL_RAISE": [.shoulders], "SHRUG": [.traps],
        "CURL": [.biceps], "TRICEPS_EXTENSION": [.triceps],
        "PLANK": [.abs], "CRUNCH": [.abs], "SIT_UP": [.abs], "CORE": [.abs], "LEG_RAISE": [.abs],
        "HYPEREXTENSION": [.lowerBack], "CARRY": [.forearms, .traps],
    ]
    static let secondary: [String: [MuscleGroup]] = [
        "SQUAT": [.lowerBack, .adductors], "LUNGE": [.hamstrings, .adductors], "LEG_PRESS": [.hamstrings],
        "DEADLIFT": [.lowerBack, .forearms], "HIP_RAISE": [.hamstrings], "LEG_CURL": [.glutes], "HIP_STABILITY": [.abs, .adductors],
        "HIP_SWING": [.lowerBack], "CALF_RAISE": [], "BENCH_PRESS": [.triceps, .shoulders], "PUSH_UP": [.triceps, .shoulders],
        "CHEST_FLY": [.shoulders], "REVERSE_FLY": [.traps, .lats], "ROW": [.biceps, .traps], "PULL_UP": [.biceps], "LAT_PULLDOWN": [.biceps],
        "SHOULDER_PRESS": [.triceps, .traps], "LATERAL_RAISE": [.traps], "CURL": [.forearms],
        "PLANK": [.obliques, .lowerBack], "CRUNCH": [.obliques], "SIT_UP": [.obliques], "CORE": [.obliques], "LEG_RAISE": [.obliques],
    ]
}
