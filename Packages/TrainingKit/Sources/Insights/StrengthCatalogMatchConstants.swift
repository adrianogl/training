import Foundation

enum StrengthCatalogMatchConstants {
    static let minimumWordLength = 3
    static let stopwords: Set<String> = ["com", "de", "do", "da", "dos", "das", "no", "na", "nos", "nas", "em", "e", "a", "o", "para", "por", "ao"]
    static let neutralWords: Set<String> = ["reto", "reta", "direta", "direto", "livre", "simples", "tradicional", "maquina", "aparelho", "banco"]
    static let modifiers: Set<String> = [
        "inclinado", "declinado", "unilateral", "alternado", "sentado", "deitado", "fechada", "aberta", "neutra", "invertido", "reverso",
        "salto", "bola", "argola", "suspensao", "descendente", "bosu", "suica", "argolas", "ajoelhado", "chao", "smith",
    ]
    static let equipment: [String: [String]] = [
        "haltere": ["halter", "halteres", "haltere", "dumbbell"],
        "barra": ["barra", "barbell"],
        "cabo": ["cabo", "cabos", "polia", "crossover"],
        "smith": ["smith"],
        "kettlebell": ["kettlebell", "kettle"],
        "elastico": ["elastico", "faixa", "band", "miniband"],
    ]
    static let synonyms: [String: String] = [
        "inclinada": "inclinado", "declinada": "declinado", "alternada": "alternado", "sentada": "sentado", "deitada": "deitado",
        "frente": "frontal", "joelhos": "joelho", "pernas": "perna", "bracos": "braco",
    ]

    struct Alias {
        let phrases: [String]
        let equipment: String?
        let id: String
    }

    static let aliases: [Alias] = [
        Alias(phrases: ["supino inclinado"], equipment: "haltere", id: "BENCH_PRESS/INCLINE_DUMBBELL_BENCH_PRESS"),
        Alias(phrases: ["supino inclinado"], equipment: "smith", id: "BENCH_PRESS/INCLINE_SMITH_MACHINE_BENCH_PRESS"),
        Alias(phrases: ["supino inclinado"], equipment: nil, id: "BENCH_PRESS/INCLINE_BARBELL_BENCH_PRESS"),
        Alias(phrases: ["supino declinado"], equipment: nil, id: "BENCH_PRESS/DECLINE_DUMBBELL_BENCH_PRESS"),
        Alias(phrases: ["supino"], equipment: "haltere", id: "BENCH_PRESS/DUMBBELL_BENCH_PRESS"),
        Alias(phrases: ["supino"], equipment: "smith", id: "BENCH_PRESS/SMITH_MACHINE_BENCH_PRESS"),
        Alias(phrases: ["supino"], equipment: "barra", id: "BENCH_PRESS/BARBELL_BENCH_PRESS"),
        Alias(phrases: ["supino"], equipment: nil, id: "BENCH_PRESS/BENCH_PRESS"),
        Alias(phrases: ["crossover", "cross over", "cruzamento de cabos"], equipment: nil, id: "FLYE/CABLE_CROSSOVER"),
        Alias(phrases: ["crucifixo inclinado"], equipment: nil, id: "FLYE/INCLINE_DUMBBELL_FLYE"),
        Alias(phrases: ["crucifixo"], equipment: "haltere", id: "FLYE/DUMBBELL_FLYE"),
        Alias(phrases: ["puxada fechada", "puxada triangulo", "puxada com triangulo"], equipment: nil, id: "PULL_UP/CLOSE_GRIP_LAT_PULLDOWN"),
        Alias(phrases: ["puxada aberta"], equipment: nil, id: "PULL_UP/WIDE_GRIP_LAT_PULLDOWN"),
        Alias(phrases: ["puxada", "pulldown", "pulley frente", "pulley costas"], equipment: nil, id: "PULL_UP/LAT_PULLDOWN"),
        Alias(phrases: ["remada baixa", "remada sentada"], equipment: nil, id: "ROW/SEATED_CABLE_ROW"),
        Alias(phrases: ["serrote", "remada unilateral"], equipment: nil, id: "ROW/SINGLE_ARM_NEUTRAL_GRIP_DUMBBELL_ROW"),
        Alias(phrases: ["remada curvada"], equipment: "haltere", id: "ROW/BENT_OVER_ROW_WITH_DUMBELL"),
        Alias(phrases: ["remada curvada"], equipment: nil, id: "ROW/BENT_OVER_ROW_WITH_BARBELL"),
        Alias(phrases: ["remada"], equipment: "barra", id: "ROW/BARBELL_ROW"),
        Alias(phrases: ["remada"], equipment: "haltere", id: "ROW/DUMBBELL_ROW"),
        Alias(phrases: ["rosca scott"], equipment: nil, id: "CURL/EZ_BAR_PREACHER_CURL"),
        Alias(phrases: ["rosca martelo"], equipment: "cabo", id: "CURL/CABLE_HAMMER_CURL"),
        Alias(phrases: ["rosca martelo"], equipment: nil, id: "CURL/DUMBBELL_HAMMER_CURL"),
        Alias(phrases: ["rosca alternada"], equipment: nil, id: "CURL/STANDING_ALTERNATING_DUMBBELL_CURLS"),
        Alias(phrases: ["rosca direta", "rosca biceps"], equipment: nil, id: "CURL/BARBELL_BICEPS_CURL"),
        Alias(phrases: ["triceps corda"], equipment: nil, id: "TRICEPS_EXTENSION/ROPE_PRESSDOWN"),
        Alias(phrases: ["triceps frances"], equipment: nil, id: "TRICEPS_EXTENSION/OVERHEAD_DUMBBELL_TRICEPS_EXTENSION"),
        Alias(phrases: ["triceps testa"], equipment: nil, id: "TRICEPS_EXTENSION/LYING_EZ_BAR_TRICEPS_EXTENSION"),
        Alias(phrases: ["triceps pulley", "triceps polia", "triceps na polia", "triceps barra"], equipment: nil, id: "TRICEPS_EXTENSION/TRICEPS_PRESSDOWN"),
        Alias(phrases: ["desenvolvimento"], equipment: "haltere", id: "SHOULDER_PRESS/DUMBBELL_SHOULDER_PRESS"),
        Alias(phrases: ["elevacao lateral"], equipment: nil, id: "LATERAL_RAISE/DUMBBELL_LATERAL_RAISE"),
        Alias(phrases: ["elevacao frontal"], equipment: nil, id: "LATERAL_RAISE/FRONT_RAISE"),
        Alias(phrases: ["leg press", "leg 45"], equipment: nil, id: "SQUAT/LEG_PRESS"),
        Alias(phrases: ["hack"], equipment: nil, id: "SQUAT/BARBELL_HACK_SQUAT"),
        Alias(phrases: ["bulgaro"], equipment: "barra", id: "LUNGE/BARBELL_BULGARIAN_SPLIT_SQUAT"),
        Alias(phrases: ["bulgaro"], equipment: nil, id: "LUNGE/DUMBBELL_BULGARIAN_SPLIT_SQUAT"),
        Alias(phrases: ["agachamento"], equipment: "barra", id: "SQUAT/BARBELL_BACK_SQUAT"),
        Alias(phrases: ["cadeira extensora", "extensora"], equipment: nil, id: "CRUNCH/LEG_EXTENSIONS"),
        Alias(phrases: ["mesa flexora", "cadeira flexora", "flexora"], equipment: nil, id: "LEG_CURL/LEG_CURL"),
        Alias(phrases: ["stiff"], equipment: nil, id: "DEADLIFT/ROMANIAN_DEADLIFT"),
        Alias(phrases: ["levantamento terra", "terra"], equipment: "barra", id: "DEADLIFT/BARBELL_DEADLIFT"),
        Alias(phrases: ["afundo", "passada", "avanco"], equipment: "haltere", id: "LUNGE/DUMBBELL_LUNGE"),
        Alias(phrases: ["elevacao pelvica", "hip thrust"], equipment: nil, id: "HIP_RAISE/BARBELL_HIP_THRUST_WITH_BENCH"),
        Alias(phrases: ["abducao", "abdutora"], equipment: "cabo", id: "HIP_STABILITY/STANDING_CABLE_HIP_ABDUCTION"),
        Alias(phrases: ["panturrilha"], equipment: nil, id: "CALF_RAISE/CALF_RAISE"),
        Alias(phrases: ["prancha"], equipment: nil, id: "PLANK/PLANK"),
        Alias(phrases: ["flexao de braco", "flexao de bracos"], equipment: nil, id: "PUSH_UP/PUSH_UP"),
        Alias(phrases: ["encolhimento"], equipment: "barra", id: "SHRUG/BARBELL_SHRUG"),
    ]
}
