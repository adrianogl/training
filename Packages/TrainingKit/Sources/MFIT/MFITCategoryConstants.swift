enum MFITCategoryConstants {
    static let byName: [(keywords: [String], category: String)] = [
        (["crucifixo inverso", "voador inverso"], "REVERSE_FLY"),
        (["elevação pélvica", "elevacao pelvica", "ponte", "hip thrust"], "HIP_RAISE"),
        (["abdução", "abducao", "glúteo na polia", "gluteo na polia", "coice", "unipodal"], "HIP_STABILITY"),
        (["adução", "aducao"], "HIP_ADDUCTION"),
        (["panturrilha"], "CALF_RAISE"),
        (["flexora", "stiff", "bom dia"], "LEG_CURL"),
        (["extensora"], "LEG_EXTENSION"),
        (["terra", "levantamento", "sumô", "sumo"], "DEADLIFT"),
        (["búlgaro", "bulgaro", "afundo", "avanço", "avanco", "passada", "subida na caixa"], "LUNGE"),
        (["leg press", "leg 45", "agachamento", "hack", "squat"], "SQUAT"),
        (["supino", "crucifixo", "peck", "crossover", "voador"], "BENCH_PRESS"),
        (["flexão de braço", "flexao de braco", "flexão de braços", "flexao de bracos", "flexão tirando"], "PUSH_UP"),
        (["remada", "serrote"], "ROW"),
        (["pulley", "puxada", "barra fixa", "pull"], "PULL_UP"),
        (["desenvolvimento", "elevação lateral", "elevacao lateral", "elevação frontal"], "SHOULDER_PRESS"),
        (["encolhimento"], "SHRUG"),
        (["tríceps", "triceps", "francês", "frances", "mergulho"], "TRICEPS_EXTENSION"),
        (["rosca", "bíceps", "biceps"], "CURL"),
        (["prancha"], "PLANK"),
        (["oblíquo", "obliquo"], "CORE"),
        (["abdominal", "abdômen", "abdomen", "infra", "supra", "rodinha"], "CRUNCH"),
        (["lombar", "hiperextensão", "hiperextensao"], "HYPEREXTENSION"),
    ]

    static let byGroup: [String: String] = [
        "peitoral": "BENCH_PRESS", "dorsal": "ROW", "costas": "ROW", "tríceps": "TRICEPS_EXTENSION",
        "bíceps": "CURL", "ombro": "SHOULDER_PRESS", "ombros": "SHOULDER_PRESS", "deltoide": "SHOULDER_PRESS",
        "panturrilha": "CALF_RAISE", "quadriceps": "LEG_EXTENSION", "quadríceps": "LEG_EXTENSION",
        "posterior": "LEG_CURL", "glúteo": "HIP_RAISE", "glúteos": "HIP_RAISE", "inferiores": "SQUAT",
        "abdômen": "CRUNCH", "abdomen": "CRUNCH", "lombar": "HYPEREXTENSION", "trapézio": "SHRUG",
    ]
}
