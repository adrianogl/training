import Foundation
import Insights
import WorkoutAnalysis

extension WorkoutChatStore {
    static let trainer = WorkoutChatStore(folder: URL.applicationSupportDirectory.appending(path: TrainerChatConstants.folderName))
}

enum TrainerChatConstants {
    static let folderName = "TrainerConversations"
    static let key: Int64 = 1
    static let title = "Perguntar ao treinador"
    static let ask = "Perguntar"
    static let swapVerbPattern = #"\b(troc|invert|mov|mud|pass|transfer)\w*"#
    static let weekdayStems = ["segunda", "terca", "quarta", "quinta", "sexta", "sabado", "domingo"]
    static let swapLabelFormat = "Trocar %@ e %@"
    static let requestLabel = "Pedir readequação"
    static let upcomingDays = 7
    static let recentRuns = 5
    static let recentVersions = 3
    static let requestPatterns: [(category: TrainerRequestCategory, pattern: String)] = [
        (.pain, #"\b(dor|dores|doendo|doi|lesao|machucad\w*|machuquei|incomodo)\b"#),
        (.travel, #"\b(viagem|viagens|viajar|viajo|viajando|viajei)\b"#),
        (.fatigue, #"\b(cansaco|cansado|cansada|exausto|exausta|esgotad\w*)\b"#),
        (.moreTime, #"\bmais tempo\b"#),
        (.goalChanged, #"\b(mudou|mudei|mudar|nova) (a |de )?meta\b"#),
    ]
    static let suggestions = [
        "Por que o treino de limiar está assim?",
        "Posso trocar sábado e domingo?",
        "Por que a força não reduz a corrida?",
        "Como está o longão em blocos?",
        "Vou viajar, o que muda?",
    ]
    static let goalFormat = "Meta: %@"
    static let goalTimeFormat = ", tempo alvo %@"
    static let countdownFormat = ", faltam %d dias"
    static let weekFormat = "Semana atual: %d de %d, fase %@, %@ km planejados, longão de %@ km"
    static let recoverySuffix = ", semana de recuperação"
    static let noWeek = "Hoje está fora das semanas do plano."
    static let pacesFormat = "Paces: fácil %@, longão %@, limiar %@%@, VO2 %@%@."
    static let sourceFormat = " (%@)"
    static let strengthPrefix = "Força: "
    static let longModeBlocks = "Longão em blocos, "
    static let longModeContinuous = "Longão contínuo."
    static let upcomingHeader = "Próximos 7 dias:"
    static let restLine = "Folga"
    static let editedSuffix = ", editado por você"
    static let methodPrefix = "método "
    static let structurePrefix = "estrutura: "
    static let rationalePrefix = "Por que: "
    static let runsEmpty = "Sem treinos recentes."
    static let heartRateFormat = "FC média %d bpm"
    static let onTargetFormat = "%d de %d tiros no alvo"
    static let versionFormat = "v%d (%@): %@"
    static let rules = """
    Regras do plano: no limiar, cada bloco tem até 1 min/km de diferença para o pace de limiar. No VO2, o pace é 0,7 do pace do tiro. \
    O longão pode ser em blocos, com pausas planejadas. A força não reduz a corrida da semana. Toda prescrição é por distância, nunca por tempo.
    """
    static let sourceNames: [TrainerPaceSource: String] = [
        .work: "dos seus treinos de qualidade",
        .prediction: "da previsão da Garmin",
        .history: "do histórico",
        .fallback: "estimado",
        .manual: "ajustado por você",
    ]

    static func runKindName(_ kind: RunKind) -> String {
        switch kind {
        case .intervals: "intervalado"
        case .tempo: "tempo"
        case .race: "prova"
        case .long: "longão"
        case .easy: "leve"
        }
    }

    private static let sharedRules = """
    Responda em duas a quatro frases, em segunda pessoa, de forma direta e calma, sem exclamação, sem emoji e sem listas.
    Use só os dados recebidos e o que as ferramentas devolverem. Cite os números no mesmo formato em que vieram e não invente nenhum número.
    Se o dado não existir, diga que não tem esse dado. Você não altera o plano: quando fizer sentido mudar algo, diga o que mudaria e que o atleta pode pedir a mudança pelas telas do treinador.
    """

    static let copy = WorkoutChatCopy(
        instructions: "Você é o treinador de corrida do atleta e responde perguntas sobre o plano de treino dele, em português do Brasil.\n" + sharedRules
            + "\nQuando a pergunta precisar do motivo de um treino, dos treinos recentes ou das últimas mudanças do plano, chame a ferramenta certa antes de responder.",
        factsHeader: "Resumo do plano:",
        historyHeader: "Conversa anterior sobre o plano:",
        welcome: "Pode perguntar por que um treino está assim, como estão os paces, o longão e a força, ou o que muda se você viajar ou sentir dor.",
        placeholder: "Pergunte sobre o plano",
        blocksDescription: "Devolve o motivo de cada treino dos próximos 7 dias.",
        similarDescription: "Devolve os últimos 5 treinos feitos, do mais recente para o mais antigo.",
        dayDescription: "Devolve as últimas mudanças do plano e o motivo de cada uma.",
        blocksNote: "leu o motivo dos treinos", dayNote: "leu as mudanças do plano",
        blocksName: "motivo_dos_treinos", similarName: "ultimos_treinos", dayName: "ultimas_mudancas",
        similarNote: "leu os últimos treinos"
    )
}
