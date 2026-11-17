import Storage

enum GoalsConstants {
    static let sectionTitle = "Metas"
    static let archivedTitle = "Arquivadas"
    static let newGoal = "Nova meta"
    static let empty = "Nenhuma meta além do volume semanal."
    static let footer = "As metas sincronizam com o site e entram nas análises dos treinos."
    static let kindTitles: [GoalKind: String] = [.time: "Tempo numa distância", .continuousLong: "Longão sem pausas"]
    static let kindHints: [GoalKind: String] = [
        .time: "Ex.: 10 km em 40 min, com prazo opcional.",
        .continuousLong: "Distância e pace-alvo, sem nenhuma parada.",
    ]
    static let kindScopes: [GoalKind: String] = [.time: "Vale para tiros, ritmo e provas", .continuousLong: "Vale para longões"]
    static let distances: [(km: Double, label: String)] = [(5, "5 km"), (10, "10 km"), (21.0975, "21,1 km"), (42.195, "42,2 km")]
    static let timeTitleFormat = "%@ em %@"
    static let longTitleFormat = "%@ km sem pausas"
    static let timeLineFormat = "%@/km"
    static let deadlineFormat = " · até %@"
    static let longLineFormat = "%@ km a %@/km ou mais rápido"
    static let editorTitleNew = "Nova meta"
    static let editorTitleEdit = "Meta"
    static let kindLabel = "Tipo"
    static let distanceLabel = "Distância"
    static let timeLabel = "Tempo-alvo"
    static let timePlaceholder = "40:00"
    static let targetLabel = "Alvo"
    static let targetModeTitles: [GoalTargetMode: String] = [.time: "Tempo", .pace: "Pace"]
    static let derivedPaceLabel = "Pace"
    static let derivedTimeLabel = "Tempo"
    static let paceUnitFormat = "%@ /km"
    static let derivedHints: [GoalTargetMode: String] = [.time: "O pace é calculado a partir do tempo.", .pace: "O tempo é calculado a partir do pace."]
    static let hasDeadline = "Com prazo"
    static let deadlineLabel = "Prazo"
    static let longDistanceLabel = "Distância mínima (km)"
    static let longDistancePlaceholder = "16"
    static let paceLabel = "Pace-alvo"
    static let pacePlaceholder = "4:50"
    static let save = "Salvar"
    static let archive = "Arquivar"
    static let unarchive = "Reativar"
    static let delete = "Apagar meta"
    static let deleteQuestion = "Apagar esta meta no app e no site?"
    static let invalidTime = "Confira o tempo, como 40:00 ou 1:39:00."
    static let invalidDistance = "Confira a distância."
    static let invalidPace = "Confira o pace, como 4:50."
    static let invalidDeadline = "O prazo não pode ficar antes de hoje."
    static let minTargetSeconds = 60.0
    static let maxTargetSeconds = 86_400.0
    static let minPace = 150.0
    static let maxPace = 900.0
    static let maxDistanceKm = 100.0

    static let weeklyTitle = "Volume semanal"
    static let weeklyNone = "sem meta"
    static let weeklyKmFormat = "%d km"
    static let weeklyPerWeekFormat = "%d km por semana"
    static let weeklyFooter = "A meta semanal aparece no volume semanal e na semana de treino da Hoje."
    static let allGoals = "Todas as metas"
    static let close = "Fechar"
    static let newGoalPlus = "+ Nova meta"

    static let cardTitle = "Metas"
    static let cardCountFormat = "%d ativas"
    static let cardCountOne = "1 ativa"
    static let achievedFormat = "cumprida em %@"
    static let remainingFormat = "faltam %@"
    static let ahead = "previsão abaixo"
    static let runsFormat = "%d de %d"
    static let todayLabel = "previsão hoje"
    static let goalLabel = "meta"
    static let noPrediction = "Ainda sem esforços para prever esta distância."
    static let crossingOnFormat = "Na tendência de 90 dias, chega na meta por volta de %@."
    static let crossingOnDeadlineFormat = "Na tendência de 90 dias, chega na meta por volta de %@, %@ do prazo."
    static let beforeDeadline = "antes"
    static let afterDeadline = "depois"
    static let crossingBeaten = "A previsão de hoje já está abaixo da meta. Falta fazer o tempo numa corrida."
    static let crossingUnreachable = "Na tendência atual, a meta não chega no horizonte de um ano."
    static let longCaptionFormat = "Maior trecho sem parar nos últimos longões, em km. A meta é %@ km a %@/km."
    static let longEmpty = "Ainda sem longões perto dessa distância."
    static let barHeight: Double = 10
    static let runsHeight: Double = 64
    static let noDataHeightShare = 0.08
}

enum GoalsChatConstants {
    static let prefix = "Meta: "
    static let timeTodayFormat = ", previsão de hoje %@"
    static let timeRemainingFormat = ", faltam %@"
    static let timeAhead = ", previsão de hoje já abaixo da meta"
    static let achievedFormat = ", cumprida em %@"
    static let deadlineFormat = ", prazo %@"
    static let longFormat = "longão de %@ km a %@/km sem pausas"
    static let longRunsFormat = "; %d de %d longões recentes cumpriram"
    static let longEmpty = "; ainda sem longões recentes"
    static let longBestFormat = "; melhor trecho contínuo %@ km"
    static let longAchievedFormat = "; cumprida em %@"
}
