enum WorkoutChatConstants {
    static let folderName = "Conversations"
    static let indexName = "index.json"
    static let historyLimit = 12
    static let ask = "Perguntar sobre o treino"
    static let hasChat = "Tem conversa com a Apple Intelligence"
    static let unavailable = "Ative a Apple Intelligence nos Ajustes do aparelho para conversar sobre o treino."
    static let placeholder = "Pergunte sobre este treino"
    static let onDevice = "Apple Intelligence · no aparelho"
    static let thinking = "Pensando…"
    static let failed = "Não consegui responder agora. Tente de novo."
    static let unverified = "Confira: a resposta cita números que não estão nos dados do treino."
    static let today = "hoje"
    static let yesterday = "ontem"
    static let welcome = "Pode perguntar sobre os blocos, as recuperações, a FC, as zonas ou comparar com treinos anteriores."
    static let toolBlocks = "leu os blocos"
    static let toolSimilar = "buscou os treinos parecidos"
    static let toolDay = "leu os dados do dia"
    static let suggestionsIntervals = ["Por que algum tiro saiu fora do alvo?", "Meu trote foi rápido demais?", "Foi melhor que o treino parecido anterior?", "Eu estava cansado antes do treino?", "O que mudo no próximo?"]
    static let suggestionsContinuous = ["O ritmo caiu no fim?", "Minha FC subiu demais?", "Foi melhor que o treino parecido anterior?", "Eu estava cansado antes do treino?", "O que mudo no próximo?"]
    static let plannedFolderName = "PlannedConversations"
    static let askPlanned = "Planejar com a Apple Intelligence"
    static let raceFolderName = "RaceConversations"
    static let evolutionFolderName = "EvolutionConversations"
    static let evolutionKey: Int64 = 0
    static let askRace = "Conversar sobre a prova"
    static let askEvolution = "Conversar sobre a evolução"
    static let evolutionTitle = "Evolução"
    static let suggestionsNextRace = ["Minha meta é realista?", "Como divido o ritmo na prova?", "O que falta no bloco?", "Como faço o polimento?", "Onde o percurso pesa mais?"]
    static let suggestionsCompletedRace = ["Por que fiquei longe da meta?", "Onde perdi tempo?", "Larguei rápido demais?", "O que mudo na próxima prova?", "Qual meta faz sentido agora?"]
    static let suggestionsEvolution = ["Estou melhorando?", "O que mais evoluiu?", "O que piorou?", "Vou bater a meta da prova?", "Treinei forte demais nas últimas semanas?"]
    private static let sharedRules = """
    Responda em duas a quatro frases, de forma direta e calma, sem exclamação, sem emoji e sem listas.
    Use só os dados recebidos e o que as ferramentas devolverem. Cite os números no mesmo formato em que vieram e não invente nenhum número.
    Se o dado não existir, diga que não tem esse dado e diga o que você pode responder.
    """
    static let nextRaceCopy = WorkoutChatCopy(
        instructions: "Você é um treinador de corrida conversando com o seu atleta sobre a próxima prova dele, em português do Brasil.\n" + sharedRules
            + "\nQuando a pergunta precisar da estratégia km a km, do volume das semanas do bloco ou do polimento, chame a ferramenta certa antes de responder.",
        factsHeader: "Dados da prova:",
        historyHeader: "Conversa anterior sobre esta prova:",
        welcome: "Pode perguntar sobre a meta, a estratégia de ritmo, o bloco de treino, o polimento ou o percurso.",
        placeholder: "Pergunte sobre a prova",
        blocksDescription: "Devolve a estratégia de pace km a km da prova.",
        similarDescription: "Devolve os km de cada semana do bloco de treino até a prova.",
        dayDescription: "Devolve o plano de polimento: km feitos e alvo de cada semana até a prova.",
        blocksNote: "leu a estratégia km a km", dayNote: "leu o polimento",
        blocksName: "estrategia_km_a_km", similarName: "semanas_do_bloco", dayName: "polimento",
        similarNote: "leu as semanas do bloco"
    )
    static let completedRaceCopy = WorkoutChatCopy(
        instructions: "Você é um treinador de corrida conversando com o seu atleta sobre uma prova que ele já correu, em português do Brasil.\n" + sharedRules
            + "\nQuando a pergunta precisar dos parciais km a km ou da análise da prova, chame a ferramenta certa antes de responder.",
        factsHeader: "Dados da prova:",
        historyHeader: "Conversa anterior sobre esta prova:",
        welcome: "Pode perguntar onde você perdeu ou ganhou tempo, como foi o ritmo, o que mudar na próxima e que meta faz sentido agora.",
        placeholder: "Pergunte sobre a prova",
        blocksDescription: "Devolve o pace de cada km da prova e o pace planejado, quando existir.",
        similarDescription: "Devolve a análise da prova: o que ajustar, o que foi bem e o que fazer na próxima.",
        dayDescription: "Devolve a previsão da véspera e a meta da prova.",
        blocksNote: "leu os parciais", dayNote: "leu a previsão da véspera",
        blocksName: "parciais_km_a_km", similarName: "analise_da_prova", dayName: "previsao_e_meta",
        similarNote: "leu a análise da prova"
    )
    static let evolutionCopy = WorkoutChatCopy(
        instructions: "Você é um treinador de corrida conversando com o seu atleta sobre a evolução dele nos últimos meses, em português do Brasil.\n" + sharedRules
            + "\nQuando a pergunta precisar das métricas do período, dos recordes ou da distribuição por zona das últimas semanas, chame a ferramenta certa antes de responder.",
        factsHeader: "Resumo da evolução:",
        historyHeader: "Conversa anterior sobre a evolução:",
        welcome: "Pode perguntar se você está melhorando, o que evoluiu ou piorou, como estão os recordes e se a meta da prova está ao alcance.",
        placeholder: "Pergunte sobre a sua evolução",
        blocksDescription: "Devolve cada métrica do período escolhido: valor atual, média, mínimo, máximo e variação.",
        similarDescription: "Devolve os recordes pessoais com data.",
        dayDescription: "Devolve o tempo em cada zona de FC nas últimas semanas.",
        blocksNote: "leu as métricas", dayNote: "leu as zonas das semanas",
        blocksName: "metricas_do_periodo", similarName: "recordes", dayName: "zonas_por_semana",
        similarNote: "leu os recordes"
    )
    static let suggestionsPlannedIntervals = ["Como distribuo o ritmo nos tiros?", "O que faço se a FC passar do limite?", "Estou recuperado para esse treino?", "Como foi da última vez?", "Qual o melhor horário para correr?"]
    static let suggestionsPlannedContinuous = ["Que ritmo devo segurar?", "O que faço se a FC subir demais?", "Estou recuperado para esse treino?", "Como foi da última vez?", "Qual o melhor horário para correr?"]
    static let doneCopy = WorkoutChatCopy(
        instructions: instructions, factsHeader: factsHeader, historyHeader: historyHeader, welcome: welcome, placeholder: placeholder,
        blocksDescription: "Devolve pace, FC e situação de cada bloco do treino (aquecimento, tiros, recuperações, desaquecimento).",
        similarDescription: "Devolve data, pace médio e FC média dos treinos parecidos com este, incluindo este.",
        dayDescription: "Devolve a prontidão, o sono e a VFC da noite antes do treino.",
        blocksNote: toolBlocks, dayNote: toolDay
    )
    static let plannedCopy = WorkoutChatCopy(
        instructions: """
        Você é um treinador de corrida ajudando o seu atleta a se preparar para um treino que ele ainda vai fazer, em português do Brasil.
        Responda em duas a quatro frases, de forma direta e calma, sem exclamação, sem emoji e sem listas.
        Use só os dados recebidos e o que as ferramentas devolverem. Cite os números no mesmo formato em que vieram e não invente nenhum número.
        Quando a pergunta precisar dos passos do treino, de corridas parecidas anteriores ou da recuperação de hoje, chame a ferramenta certa antes de responder.
        Pode dar orientação geral de treino sem números quando o dado não existir, e diga quando não tiver o dado.
        """,
        factsHeader: "Treino planejado:",
        historyHeader: "Conversa anterior sobre este treino planejado:",
        welcome: "Pode perguntar como fazer cada trecho, que ritmo segurar, o que fazer se a FC subir ou se você está pronto para o treino.",
        placeholder: "Pergunte sobre o treino planejado",
        blocksDescription: "Devolve os passos planejados do treino, com distância ou tempo, pace e limite de FC de cada um.",
        similarDescription: "Devolve data, distância, pace médio e FC média das corridas anteriores parecidas com este treino.",
        dayDescription: "Devolve a prontidão de hoje, os km da semana e os dias desde o último treino forte.",
        blocksNote: "leu os passos planejados", dayNote: "leu a recuperação e a semana"
    )
    static let instructions = """
    Você é um treinador de corrida conversando com o seu atleta sobre um treino que ele já fez, em português do Brasil.
    Responda em duas a quatro frases, de forma direta e calma, sem exclamação, sem emoji e sem listas.
    Use só os dados recebidos e o que as ferramentas devolverem. Cite os números no mesmo formato em que vieram e não invente nenhum número.
    Quando a pergunta precisar de detalhes dos blocos, de treinos anteriores ou dos dados do dia, chame a ferramenta certa antes de responder.
    Se o dado não existir, diga que não tem esse dado e diga o que você pode responder.
    """
    static let factsHeader = "Dados do treino:"
    static let historyHeader = "Conversa anterior sobre este treino:"
}
