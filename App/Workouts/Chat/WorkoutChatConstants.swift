enum WorkoutChatConstants {
    static let folderName = "Conversations"
    static let indexName = "index.json"
    static let historyLimit = 12
    static let askFormat = "Perguntar sobre o treino · %d"
    static let ask = "Perguntar sobre o treino"
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
    static let askPlannedFormat = "Planejar com a Apple Intelligence · %d"
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
