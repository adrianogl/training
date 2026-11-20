import Narrative

enum DetailedCoachConstants {
    static let elevationEffectSeconds = 3.0
    static let titles: [DetailedCoachPart: String] = [
        .workout: "O treino",
        .context: "No contexto dos seus treinos",
        .history: "O que o histórico explica",
        .positive: "O lado bom",
        .next: "Para o próximo",
    ]
    static let maxSentences = 6
    static let maxCharacters: [DetailedCoachPart: Int] = [
        .workout: 900,
        .context: 700,
        .history: 800,
        .positive: 600,
        .next: 700,
    ]
    static let focus: [DetailedCoachPart: String] = [
        .workout: "Conte o que aconteceu no treino, do começo ao fim, com os km e os números dos fatos.",
        .context: "Compare este treino com os parecidos e diga se foi exceção ou padrão.",
        .history: "Explique o que o histórico mostra sobre o motivo de o treino ter saído assim.",
        .positive: "Destaque o que foi bem e o que isso indica sobre a forma do atleta.",
        .next: "Diga o que fazer no próximo treino do mesmo tipo, na ordem dos fatos, com o motivo de cada ação.",
    ]
    static let instructions = """
    Você é um treinador de corrida e escreve, em português do Brasil, uma parte da análise detalhada de um treino do seu atleta, falando diretamente com ele.
    Trate o atleta por "você", nunca por "o atleta" ou na terceira pessoa.
    Escreva um único parágrafo corrido, de três a cinco frases, como um treinador falaria depois do treino.
    Ligue causa e efeito quando os fatos permitirem e não invente causa que eles não mostrem.
    Não tire conclusão que não esteja nos fatos, como "desempenho acima do esperado".
    Cada frase traz uma informação nova: não repita a mesma ideia com outras palavras.
    Use só os fatos recebidos. Cite os números no mesmo formato em que vieram e não use nenhum número que não esteja nos fatos.
    Tom calmo e direto, sem exclamação, sem emoji, sem listas e sem títulos.
    """ + "\n" + CoachFeedbackConstants.personRule + "\n" + CoachFeedbackConstants.claimsRule

    static func instructions(for part: DetailedCoachPart) -> String {
        instructions + "\n" + (focus[part] ?? "")
    }

    static func limits(for part: DetailedCoachPart) -> CoachLimits {
        CoachLimits(maxCharacters: maxCharacters[part] ?? 700, maxSentences: maxSentences)
    }
}

enum DetailedCoachText {
    static let paceAverage = "O pace médio foi de %@/km em %d km."
    static let stableRange = "Do km 1 ao km %d o pace ficou entre %@ e %@/km."
    static let stableSingle = "Do km 1 ao km %d o pace ficou em %@/km."
    static let afterFade = "Do km %d em diante o pace médio foi de %@/km."
    static let heartRateRange = "A FC foi de %d para %d bpm do primeiro ao último km."
    static let climbKm = "O km %d subiu %d m e saiu a %@/km, o equivalente a %@/km no plano."
    static let descentKm = "O km %d desceu %d m e saiu a %@/km, o equivalente a %@/km no plano."
    static let maxElevationFacts = 4
    static let comparedWith = "Comparado com %d treinos parecidos dos últimos %d dias."
    static let completionVersus = "Você fez %d%% da distância; nos parecidos, a média foi %d%%."
    static let fadeVersus = "O pace começou a cair no km %d; nos parecidos, a média foi o km %d."
    static let driftVersus = "A deriva da FC foi de %d%%; nos parecidos, a média foi %d%%."
    static let recommendation = "%@. %@"
}
