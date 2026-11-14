import WorkoutAnalysis

enum WorkoutFeedbackConstants {
    static let visibleEntries = 4
    static let priority: [FindingKind] = [
        .blockOffTarget, .stepIncomplete, .zoneAboveTarget, .cardiacDrift, .paceFade, .hardOnLowReadiness, .highAcuteChronic,
        .lowerHeartRateThanBefore, .goodRecovery, .steadyPace, .blockInTarget,
    ]

    static let slower = ("mais lento que o alvo", "mais lentos que o alvo", "mais lenta que o alvo", "mais lentas que o alvo")
    static let faster = ("mais rápido que o alvo", "mais rápidos que o alvo", "mais rápida que o alvo", "mais rápidas que o alvo")
    static let notExecuted = ("não feito", "não feitos", "não feita", "não feitas")
    static let incomplete = ("incompleto", "incompletos", "incompleta", "incompletas")
    static let heartRateAbove = "com FC acima do alvo"
    static let heartRateBelow = "com FC abaixo do alvo"
    static let zoneFormat = "em Z%d"
    static let drift = "com deriva cardíaca"
    static let fade = "com queda de ritmo no fim"
    static let recovered = "com a FC caindo rápido"
    static let lowerHeartRate = "com FC menor que da última vez"
    static let steady = "com pace constante"
    static let inTargetFormat = "%d de %d %@ no alvo"
    static let allInTargetFormat = "Os %d %@ no alvo"

    static let target = "alvo"
    static let versus = "vs."
    static let samePace = "mesmo pace"
    static let fromPeakFormat = "−%d a −%d bpm desde o pico"
    static let jogAt = "trote a"
    static let and = "e"
    static let driftFormat = "%d → %d bpm (+%d%%)"

    static let whySlowerGroup = "Ficaram abaixo do estímulo pedido para o treino."
    static let whyHighestRecoveryFormat = "O %@ veio depois da recuperação mais alta do treino (%d bpm)."
    static let whyNextBlockFormat = " O %@, logo depois, ficou abaixo do alvo."

    static let openingAllFormat = "Treino cumprido: os %d %@ saíram no alvo, com média de %@/km."
    static let openingGoodFormat = "Bom treino: %d dos %d %@ saíram no alvo, com média de %@/km."
    static let openingShortFormat = "Treino abaixo do planejado: %d dos %d %@ saíram no alvo, com média de %@/km."
    static let openingFreeFormat = "Corrida de %@ km a %@/km."
    static let fixesLead = "Para ajustar: "
    static let goodsLead = "O que foi bem: "

    static let nextTips: [FindingKind: String] = [
        .zoneAboveTarget: "Trote mais leve nas recuperações, para a FC baixar antes do próximo bloco.",
        .stepIncomplete: "Complete o volume prescrito ou ajuste o treino com o treinador antes de começar.",
        .cardiacDrift: "Hidrate antes e durante, e comece mais leve em dias quentes.",
        .paceFade: "Comece os blocos alguns segundos por km mais lento para segurar o ritmo até o fim.",
        .hardOnLowReadiness: "Em dia de prontidão baixa, troque o treino forte por um leve.",
        .highAcuteChronic: "Segure o volume dos próximos dias para a carga assentar.",
    ]
    static let nextSlower = "Mire o meio da faixa de pace em todos os blocos, desde o primeiro."
    static let nextFaster = "Segure os blocos dentro da faixa, sem passar do limite rápido."
    static let nextHeartRateAbove = "Reduza o ritmo quando a FC passar do alvo."
    static let nextHeartRateBelow = "Suba o ritmo até a FC entrar no alvo."
    static let nextRepeat = "Repita a estrutura: o treino saiu como planejado."
}
