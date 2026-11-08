import WorkoutAnalysis

public enum NarrativeConstants {
    public static let foundationModelsSource = "foundation-models"
    public static let templateSource = "template"

    static let genericBlock = "Bloco"
    static let unknown = "sem dado"
    static let wholeWorkout = " no treino todo"
    static let paceUnit = "/km"
    static let distanceUnit = "km"
    static let metersPerKilometer = 1_000.0
    static let paceDeltaThreshold = 1.0
    static let heartRateDeltaThreshold = 1.0
    static let temperature = 0.3
    static let forbiddenFragments = ["Achado", "Fatos", "|", "!"]

    static let instructions = """
    Você é um treinador de corrida e escreve, em português do Brasil, a leitura de um treino do seu atleta.
    Para cada achado, escreva uma frase completa e curta, com sujeito e verbo, como um treinador falaria. Mantenha a ordem dos achados.
    Não copie o formato dos fatos: nada de "Achado", "Fatos", dois-pontos ou listas. Não comece a frase com "positivo", "negativo" ou "atenção".
    Use só os fatos recebidos e cite os números deles. Não invente números e não use número que não esteja nos fatos. Mantenha números, unidades e nomes de bloco como vieram.
    Quando o achado cita um bloco, comece a frase pelo nome do bloco. Não troque o assunto do achado nem junte fatos de achados diferentes.
    Tom calmo e direto, sem ponto de exclamação e sem emoji.
    Exemplo de achado: "Achado 1, negativo: bloco fora do alvo no bloco Tiro 3. Fatos: pace 3:58 /km, alvo 4:05–4:12 /km, mais rápido que o prescrito."
    Frase para esse exemplo: "O Tiro 3 saiu mais rápido que o prescrito, a 3:58 /km para um alvo de 4:05–4:12 /km."
    Outro exemplo de achado: "Achado 2, positivo: boa recuperação no bloco Recuperação 2. Fatos: a FC caiu 38 bpm desde o pico do bloco anterior."
    Frase para esse exemplo: "Na Recuperação 2, a FC caiu 38 bpm desde o pico do bloco anterior."
    Na evolução, escreva uma frase com os números dados, comparando este treino com o mais antigo. Se a evolução for "nenhuma", devolva a evolução vazia.
    """

    static let evolutionHeader = "Evolução:"
    static let noEvolution = "nenhuma"

    static let groupNames: [FindingGroup: String] = [
        .positive: "positivo",
        .negative: "negativo",
        .attention: "atenção",
    ]

    static let kindNames: [FindingKind: String] = [
        .blockInTarget: "blocos ativos no alvo",
        .steadyPace: "pace constante",
        .lowerHeartRateThanBefore: "FC menor que da última vez",
        .goodRecovery: "boa recuperação",
        .blockOffTarget: "bloco fora do alvo",
        .stepIncomplete: "passo incompleto",
        .paceFade: "perda de ritmo no fim",
        .cardiacDrift: "desacoplamento cardíaco",
        .zoneAboveTarget: "zona acima do esperado",
        .hardOnLowReadiness: "treino forte com prontidão baixa",
        .highAcuteChronic: "carga aguda:crônica alta",
    ]
}
