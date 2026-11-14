import WorkoutAnalysis

enum WorkoutChatContextConstants {
    static let scoreFormat = "Nota do treino: %d de 100."
    static let readinessFormat = "prontidão %d"
    static let sleepFormat = "nota do sono %d"
    static let hrvFormat = "VFC da noite %d ms"
    static let hrvBaseFormat = " (base %d–%d ms)"
    static let restingFormat = "FC de repouso %d bpm"
    static let noDay = "Sem dados de recuperação para esse dia."
    static let statuses: [BlockStatus: String] = [
        .inTarget: "no alvo", .faster: "mais rápido que o alvo", .slower: "mais lento que o alvo",
        .aboveTarget: "FC acima do alvo", .belowTarget: "FC abaixo do alvo", .noTarget: "sem alvo",
        .incomplete: "incompleto", .notExecuted: "não feito",
    ]
}
