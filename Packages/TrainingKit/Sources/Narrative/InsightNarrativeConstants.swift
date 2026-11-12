import Metrics

enum InsightNarrativeConstants {
    static let readinessPrefix = "Prontidão"
    static let separator = " · "
    static let aboveNormal = "acima"
    static let belowNormal = "abaixo"
    static let normalSuffix = "do seu normal"
    static let topFactorCount = 2

    static let verdictPhrases: [ReadinessVerdict: String] = [
        .hard: "pode treinar forte",
        .moderate: "treino moderado",
        .rest: "dia de descanso",
    ]

    static let componentNames: [ReadinessComponent: String] = [
        .hrv: "HRV",
        .sleep: "sono",
        .bodyBattery: "Body Battery",
        .load: "carga",
    ]

    static let readinessRequiredWords: [ReadinessVerdict: [String]] = [
        .hard: ["forte"],
        .moderate: ["moderado"],
        .rest: ["descanso"],
    ]

    static let readinessForbiddenWords: [ReadinessVerdict: [String]] = [
        .hard: ["moderado", "descanso"],
        .moderate: ["forte", "descanso"],
        .rest: ["forte", "moderado"],
    ]

    static let betterWords = ["melhor", "melhorou", "melhoraram"]
    static let worseWords = ["pior", "piorou", "pioraram"]
    static let stableWord = "estável"
    static let aboveGoalWord = "acima"
    static let belowGoalWord = "abaixo"

    static let overallBetter = "Melhor que há 3 meses: %d de %d indicadores melhoraram."
    static let overallStable = "Estável em relação a 3 meses atrás."
    static let overallWorse = "Pior que há 3 meses: %d de %d indicadores pioraram."
    static let goalGapSuffix = " Faltam %@ para a meta."

    static let readinessInstructions = """
    Você é um treinador de corrida e escreve, em português do Brasil, uma frase curta sobre a prontidão do atleta para treinar hoje.
    Use só os fatos recebidos e cite todos os números deles, no mesmo formato. Não invente números e não use número que não esteja nos fatos.
    Mantenha a classificação da frase de referência, usando uma das palavras dela que indicam a direção. Não troque por classificação oposta.
    Tom calmo e direto, sem ponto de exclamação e sem emoji. Devolva só a frase.
    """

    static let overallInstructions = """
    Você é um treinador de corrida e escreve, em português do Brasil, uma frase curta sobre o estado geral do atleta comparado a 3 meses atrás.
    Use só os fatos recebidos e cite todos os números deles, no mesmo formato. Não invente números e não use número que não esteja nos fatos.
    Mantenha a classificação da frase de referência, usando uma das palavras dela que indicam a direção. Não troque por classificação oposta.
    Tom calmo e direto, sem ponto de exclamação e sem emoji. Devolva só a frase.
    """

    static let referenceHeader = "Frase de referência com os fatos:"
}
