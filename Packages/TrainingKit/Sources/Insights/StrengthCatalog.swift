public enum StrengthCatalog {
    public static func exercise(_ id: String) -> CatalogExercise? {
        all.first { $0.id == id }
    }

    public static let all: [CatalogExercise] = lower + upper + core

    public static func pattern(garminCategory: String) -> MovementPattern? {
        StrengthCatalogConstants.patternByGarminCategory[garminCategory.uppercased()]
    }

    static let lower: [CatalogExercise] = [
        CatalogExercise(id: "agachamento-livre", name: "Agachamento livre", category: "SQUAT", exerciseName: "BARBELL_BACK_SQUAT", pattern: .squat, focus: [.lower, .fullBody], equipment: .barbell, loads: [.knee, .lowerBack, .hip]),
        CatalogExercise(id: "leg-press", name: "Leg press", category: "SQUAT", exerciseName: "LEG_PRESS", pattern: .squat, focus: [.lower], equipment: .machine, loads: [.knee]),
        CatalogExercise(id: "agachamento-goblet", name: "Agachamento goblet", category: "SQUAT", pattern: .squat, focus: [.lower, .fullBody], equipment: .dumbbell, loads: [.knee]),
        CatalogExercise(id: "agachamento-peso-corpo", name: "Agachamento com peso do corpo", category: "SQUAT", pattern: .squat, focus: [.lower, .fullBody], equipment: .bodyweight, loads: [.knee]),
        CatalogExercise(id: "terra-romeno", name: "Levantamento terra romeno", category: "DEADLIFT", pattern: .hinge, focus: [.lower, .fullBody], equipment: .barbell, loads: [.lowerBack, .hip]),
        CatalogExercise(id: "terra-romeno-halteres", name: "Terra romeno com halteres", category: "DEADLIFT", pattern: .hinge, focus: [.lower, .fullBody], equipment: .dumbbell, loads: [.lowerBack, .hip]),
        CatalogExercise(id: "terra-unilateral", name: "Terra unilateral sem carga", category: "DEADLIFT", pattern: .singleLeg, focus: [.lower, .fullBody, .core], equipment: .bodyweight, loads: [.hip], unilateral: true),
        CatalogExercise(id: "elevacao-pelvica", name: "Elevação pélvica com barra", category: "HIP_RAISE", exerciseName: "BARBELL_HIP_THRUST_WITH_BENCH", pattern: .hinge, focus: [.lower, .fullBody], equipment: .barbell, loads: [.hip]),
        CatalogExercise(id: "ponte-unilateral", name: "Ponte de glúteo unilateral", category: "HIP_RAISE", exerciseName: "SINGLE_LEG_HIP_RAISE", pattern: .hinge, focus: [.lower, .fullBody, .core], equipment: .bodyweight, loads: [.hip], unilateral: true),
        CatalogExercise(id: "mesa-flexora", name: "Mesa flexora", category: "LEG_CURL", exerciseName: "WEIGHTED_LEG_CURL", pattern: .hinge, focus: [.lower], equipment: .machine, loads: [.knee]),
        CatalogExercise(id: "bulgaro-halteres", name: "Agachamento búlgaro", category: "LUNGE", exerciseName: "DUMBBELL_BULGARIAN_SPLIT_SQUAT", pattern: .singleLeg, focus: [.lower, .fullBody], equipment: .dumbbell, loads: [.knee, .hip], unilateral: true),
        CatalogExercise(id: "bulgaro-peso-corpo", name: "Búlgaro com peso do corpo", category: "LUNGE", pattern: .singleLeg, focus: [.lower], equipment: .bodyweight, loads: [.knee, .hip], unilateral: true),
        CatalogExercise(id: "afundo-reverso", name: "Afundo reverso", category: "LUNGE", pattern: .singleLeg, focus: [.lower, .fullBody], equipment: .bodyweight, loads: [.knee], unilateral: true),
        CatalogExercise(id: "subida-caixa", name: "Subida na caixa com halteres", category: "SQUAT", exerciseName: "WEIGHTED_STEP_UP", pattern: .singleLeg, focus: [.lower, .fullBody], equipment: .dumbbell, loads: [.knee], unilateral: true),
        CatalogExercise(id: "subida-degrau", name: "Subida no degrau", category: "SQUAT", pattern: .singleLeg, focus: [.lower], equipment: .bodyweight, loads: [.knee], unilateral: true),
        CatalogExercise(id: "panturrilha-em-pe", name: "Panturrilha em pé na máquina", category: "CALF_RAISE", pattern: .calf, focus: [.lower], equipment: .machine, loads: [.calfAchilles]),
        CatalogExercise(id: "panturrilha-sentado", name: "Panturrilha sentado", category: "CALF_RAISE", exerciseName: "WEIGHTED_SEATED_CALF_RAISE", pattern: .calf, focus: [.lower], equipment: .machine, loads: [.calfAchilles]),
        CatalogExercise(id: "panturrilha-halter", name: "Panturrilha unilateral com halter", category: "CALF_RAISE", pattern: .calf, focus: [.lower, .fullBody], equipment: .dumbbell, loads: [.calfAchilles], unilateral: true),
        CatalogExercise(id: "panturrilha-degrau", name: "Panturrilha unilateral no degrau", category: "CALF_RAISE", pattern: .calf, focus: [.lower, .fullBody], equipment: .bodyweight, loads: [.calfAchilles], unilateral: true),
        CatalogExercise(id: "gluteo-polia", name: "Glúteo na polia", category: "HIP_STABILITY", exerciseName: "WEIGHTED_STANDING_REAR_LEG_RAISE", pattern: .hipStability, focus: [.lower], equipment: .cable, loads: [.hip], unilateral: true),
        CatalogExercise(id: "caminhada-elastico", name: "Caminhada lateral com elástico", category: "HIP_STABILITY", pattern: .hipStability, focus: [.lower, .core], equipment: .band, loads: [.hip]),
        CatalogExercise(id: "abducao-deitado", name: "Abdução de quadril deitado", category: "HIP_STABILITY", pattern: .hipStability, focus: [.lower, .core], equipment: .bodyweight, loads: [.hip], unilateral: true),
        CatalogExercise(id: "copenhagen", name: "Prancha Copenhagen", category: "PLANK", pattern: .lateralCore, focus: [.lower, .core], equipment: .bodyweight, loads: [.hip], unilateral: true, timed: true),
        CatalogExercise(id: "saltos-caixote", name: "Saltos no caixote", category: "PLYO", pattern: .plyo, focus: [.lower, .fullBody], equipment: .bodyweight, loads: [.knee, .calfAchilles]),
        CatalogExercise(id: "afundo-salto", name: "Afundo alternado com salto", category: "PLYO", exerciseName: "ALTERNATING_JUMP_LUNGE", pattern: .plyo, focus: [.lower, .fullBody], equipment: .bodyweight, loads: [.knee, .calfAchilles]),
        CatalogExercise(id: "saltitos", name: "Saltitos de tornozelo", category: "PLYO", pattern: .plyo, focus: [.lower], equipment: .bodyweight, loads: [.calfAchilles]),
    ]

    static let upper: [CatalogExercise] = [
        CatalogExercise(id: "supino-inclinado", name: "Supino inclinado com barra", category: "BENCH_PRESS", exerciseName: "INCLINE_BARBELL_BENCH_PRESS", pattern: .horizontalPush, focus: [.upper, .fullBody], equipment: .barbell, loads: [.shoulder]),
        CatalogExercise(id: "supino-halteres", name: "Supino com halteres", category: "BENCH_PRESS", pattern: .horizontalPush, focus: [.upper, .fullBody], equipment: .dumbbell, loads: [.shoulder]),
        CatalogExercise(id: "flexao", name: "Flexão de braços", category: "PUSH_UP", exerciseName: "PUSH_UP", pattern: .horizontalPush, focus: [.upper, .fullBody], equipment: .bodyweight, loads: [.shoulder]),
        CatalogExercise(id: "flexao-mao-solta", name: "Flexão tirando as mãos do chão", category: "PUSH_UP", exerciseName: "HAND_RELEASE_PUSH_UP", pattern: .horizontalPush, focus: [.upper], equipment: .bodyweight, loads: [.shoulder]),
        CatalogExercise(id: "flexao-diamante", name: "Flexão diamante", category: "PUSH_UP", pattern: .horizontalPush, focus: [.upper], equipment: .bodyweight, loads: [.shoulder]),
        CatalogExercise(id: "flexao-pike", name: "Flexão pike", category: "PUSH_UP", pattern: .verticalPush, focus: [.upper], equipment: .bodyweight, loads: [.shoulder]),
        CatalogExercise(id: "desenvolvimento-barra", name: "Desenvolvimento com barra", category: "SHOULDER_PRESS", exerciseName: "OVERHEAD_BARBELL_PRESS", pattern: .verticalPush, focus: [.upper], equipment: .barbell, loads: [.shoulder, .lowerBack]),
        CatalogExercise(id: "desenvolvimento-halteres", name: "Desenvolvimento com halteres", category: "SHOULDER_PRESS", pattern: .verticalPush, focus: [.upper, .fullBody], equipment: .dumbbell, loads: [.shoulder]),
        CatalogExercise(id: "barra-fixa", name: "Barra fixa aberta", category: "PULL_UP", exerciseName: "WIDE_GRIP_PULL_UP", pattern: .verticalPull, focus: [.upper, .fullBody], equipment: .machine, loads: [.shoulder]),
        CatalogExercise(id: "puxada-alta", name: "Puxada alta", category: "PULL_UP", pattern: .verticalPull, focus: [.upper], equipment: .cable, loads: [.shoulder]),
        CatalogExercise(id: "remada-curvada", name: "Remada curvada supinada", category: "ROW", exerciseName: "REVERSE_GRIP_BARBELL_ROW", pattern: .horizontalPull, focus: [.upper, .fullBody], equipment: .barbell, loads: [.lowerBack]),
        CatalogExercise(id: "remada-sentado", name: "Remada sentado na polia", category: "ROW", exerciseName: "SEATED_CABLE_ROW", pattern: .horizontalPull, focus: [.upper], equipment: .cable),
        CatalogExercise(id: "remada-serrote", name: "Remada serrote com halter", category: "ROW", pattern: .horizontalPull, focus: [.upper, .fullBody], equipment: .dumbbell, unilateral: true),
        CatalogExercise(id: "remada-elastico", name: "Remada com elástico", category: "ROW", pattern: .horizontalPull, focus: [.upper], equipment: .band),
        CatalogExercise(id: "abertura-elastico", name: "Abertura de braços com elástico", category: "SHOULDER_STABILITY", pattern: .horizontalPull, focus: [.upper, .core], equipment: .band),
        CatalogExercise(id: "remada-invertida", name: "Remada invertida na mesa", category: "ROW", pattern: .horizontalPull, focus: [.upper], equipment: .bodyweight),
        CatalogExercise(id: "ytw", name: "Y, T e W deitado", category: "SHOULDER_STABILITY", pattern: .horizontalPull, focus: [.upper, .core], equipment: .bodyweight),
        CatalogExercise(id: "superman", name: "Superman", category: "HYPEREXTENSION", pattern: .hinge, focus: [.upper, .core], equipment: .bodyweight, loads: [.lowerBack]),
        CatalogExercise(id: "triceps-banco", name: "Tríceps no banco", category: "TRICEPS_EXTENSION", pattern: .horizontalPush, focus: [.upper], equipment: .bodyweight, loads: [.shoulder]),
    ]

    static let core: [CatalogExercise] = [
        CatalogExercise(id: "prancha", name: "Prancha reta", category: "PLANK", exerciseName: "PLANK", pattern: .antiExtension, focus: [.core, .fullBody], equipment: .bodyweight, timed: true),
        CatalogExercise(id: "prancha-lateral", name: "Prancha lateral", category: "PLANK", exerciseName: "SIDE_PLANK", pattern: .lateralCore, focus: [.core, .fullBody], equipment: .bodyweight, unilateral: true, timed: true),
        CatalogExercise(id: "dead-bug", name: "Dead bug", category: "CORE", pattern: .antiExtension, focus: [.core], equipment: .bodyweight),
        CatalogExercise(id: "passaro-cao", name: "Pássaro-cão", category: "CORE", pattern: .antiRotation, focus: [.core, .fullBody], equipment: .bodyweight, unilateral: true),
        CatalogExercise(id: "pallof-elastico", name: "Pallof press com elástico", category: "CORE", pattern: .antiRotation, focus: [.core], equipment: .band, unilateral: true),
        CatalogExercise(id: "pallof-polia", name: "Pallof press na polia", category: "CORE", pattern: .antiRotation, focus: [.core], equipment: .cable, unilateral: true),
        CatalogExercise(id: "rodinha", name: "Abdominal rodinha", category: "CORE", exerciseName: "KNEELING_AB_WHEEL", pattern: .antiExtension, focus: [.core], equipment: .machine, loads: [.lowerBack]),
        CatalogExercise(id: "infra-banco", name: "Abdominal infra no banco", category: "CRUNCH", exerciseName: "REVERSE_CRUNCH_ON_A_BENCH", pattern: .antiExtension, focus: [.core], equipment: .machine, loads: [.lowerBack]),
        CatalogExercise(id: "elevacao-pernas", name: "Elevação de pernas deitado", category: "LEG_RAISE", pattern: .antiExtension, focus: [.core], equipment: .bodyweight, loads: [.lowerBack]),
        CatalogExercise(id: "carregamento-unilateral", name: "Caminhada com halter de um lado", category: "CARRY", pattern: .lateralCore, focus: [.core, .fullBody], equipment: .dumbbell, unilateral: true, timed: true),
        CatalogExercise(id: "mobilidade-90-90", name: "Mobilidade de quadril 90/90", category: "WARM_UP", pattern: .mobilityHip, focus: [.core], equipment: .bodyweight, unilateral: true),
        CatalogExercise(id: "flexor-quadril", name: "Alongamento do flexor do quadril", category: "WARM_UP", pattern: .mobilityHip, focus: [.core], equipment: .bodyweight, unilateral: true, timed: true),
        CatalogExercise(id: "balanco-perna", name: "Balanço de perna frente e trás", category: "WARM_UP", pattern: .mobilityHip, focus: [.core], equipment: .bodyweight, unilateral: true),
        CatalogExercise(id: "mobilidade-tornozelo", name: "Mobilidade de tornozelo na parede", category: "WARM_UP", pattern: .mobilityAnkle, focus: [.core], equipment: .bodyweight, unilateral: true),
        CatalogExercise(id: "gato-camelo", name: "Gato-camelo", category: "WARM_UP", exerciseName: "CAT_CAMEL", pattern: .mobilityThoracic, focus: [.core], equipment: .bodyweight),
        CatalogExercise(id: "rotacao-toracica", name: "Rotação torácica em quatro apoios", category: "WARM_UP", exerciseName: "THORACIC_ROTATION", pattern: .mobilityThoracic, focus: [.core], equipment: .bodyweight, unilateral: true),
    ]
}
