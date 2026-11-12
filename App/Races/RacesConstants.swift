import Foundation
import Insights
import Metrics

enum RacesConstants {
    static let title = "Provas"
    static let upcomingTitle = "Próximas"
    static let completedTitle = "Concluídas"
    static let candidatesTitle = "Parece prova?"
    static let confirmCandidate = "Foi prova"
    static let declineCandidate = "Não foi"
    static let candidateHeartRateUnit = "bpm"
    static let emptyList = "Nenhuma prova cadastrada. Toque em + para cadastrar a primeira."
    static let addRace = "Nova prova"
    static let editRace = "Editar"
    static let prBadge = "PR"
    static let noResult = "sem resultado"
    static let today = "hoje"
    static let blockAnchor = "prova-bloco"
    static let endAnchor = "prova-fim"

    static let distanceMeters: [RaceDistanceOption: Double] = [
        .five: 5_000,
        .ten: 10_000,
        .half: 21_097.5,
        .full: 42_195,
    ]
    static let distanceTitles: [RaceDistanceOption: String] = [
        .five: "5 km",
        .ten: "10 km",
        .half: "21,1 km",
        .full: "42,2 km",
        .other: "outra",
    ]
    static let distanceTolerance = 0.5
    static let resultDistanceTolerance = 0.10
    static let sameDistanceTolerance = 0.02
    static let metersPerKm = 1_000.0
    static let secondsPerMinute = 60.0
    static let secondsPerHour = 3_600.0
    static let checklistPeriod = MetricPeriod.sixMonths
    static let blockWeeks = 12
    static let recentWeeks = 4
    static let daysPerWeek = 7
    static let blockFetchExtraDays = 35
    static let loadHistoryDays = 455

    static let assessmentWords: [GoalAssessment: String] = [
        .easy: "tranquila",
        .challenging: "desafiadora",
        .aggressive: "agressiva",
    ]
    static let referenceRaceDay = "da projeção para o dia"
    static let referenceToday = "da previsão de hoje"
    static let assessmentFormat = "Meta %@: %@%% %@ %@."
    static let below = "abaixo"
    static let above = "acima"
    static let comparedRaceDay = "Comparado com a projeção no dia da prova."
    static let comparedToday = "Comparado com a previsão de hoje (sem projeção para o dia)."
    static let noPredictionForGoal = "Sem previsão para comparar com a meta."

    static let goalLabel = "meta"
    static let todayLabel = "previsão hoje"
    static let raceDayLabel = "no dia da prova"
    static let noGoal = "Sem meta cadastrada. Edite a prova para definir uma."

    static let strategyTitle = "Estratégia por km"
    static let targetPrefix = "alvo"
    static let targetSources: [StrategyTargetSource: String] = [
        .raceDayProjection: "projeção no dia",
        .todayPrediction: "previsão hoje",
        .goal: "meta",
        .frozen: "congelado em",
    ]
    static let strategyHeaders = ["km", "trecho", "incl.", "pace", "acum."]
    static let strategyFootnote = "Toque num km para fixar um pace manual; os demais se ajustam para fechar o alvo."
    static let strategyNoGPX = "Sem altimetria: estratégia plana. Importe o GPX da prova para ajustar pela inclinação."
    static let strategyInfeasible = "Os paces manuais não fecham com o alvo atual. Limpe os paces manuais para recalcular."
    static let strategyNoTarget = "Sem previsão nem meta, não dá para montar a estratégia."
    static let clearManual = "Limpar paces manuais"
    static let recalculateAll = "Recalcular tudo"
    static let paceEditorTitle = "Pace do km %d"
    static let paceEditorSave = "Fixar"
    static let paceEditorClear = "Soltar este km"
    static let cancel = "Cancelar"
    static let minPaceSeconds = 150
    static let maxPaceSeconds = 600
    static let climbLabel = "subida"
    static let altitudeChartHeight: Double = 50

    static let blockTitle = "Bloco semana a semana"
    static let blockLegend = "sólido: feito · tracejado: projeção pela média das últimas 4 semanas"
    static let blockChartHeight: Double = 90
    static let blockReadingFormat = "Semana %d de %d do bloco. Média de %@ km nas últimas 4 semanas; maior semana do bloco com %@ km. Longão mais longo de %@ km para um alvo de %@ km. As semanas que faltam são projeção, não plano."
    static let blockReadingBeforeFormat = "O bloco de 12 semanas começa em %d semanas. Média de %@ km nas últimas 4 semanas."

    static let checklistTitle = "Checklist de prontidão"
    static let checklistTitles: [ChecklistKind: String] = [
        .vo2max: "VO2max vs início do bloco",
        .longRun: "Longão mais longo vs alvo",
        .thresholdPace: "Pace de limiar vs pace alvo",
        .hrv: "HRV vs base",
        .raceDayForm: "Forma no dia da prova (projeção)",
    ]
    static let checklistMissing: [ChecklistKind: String] = [
        .vo2max: "sem VO2max nas corridas do bloco",
        .longRun: "sem corridas no bloco",
        .thresholdPace: "sem FC de limiar ou trechos no limiar",
        .hrv: "sem HRV da noite",
        .raceDayForm: "sem carga suficiente para projetar",
    ]

    static let readingTitle = "Leitura do bloco"
    static let predictionChartTitle = "Previsão até a prova"

    static let resultLabel = "resultado"
    static let eveLabel = "previsão da véspera"
    static let noEvePrediction = "sem previsão da véspera"
    static let splitsTitle = "Parciais"
    static let lessonTitle = "O que a prova ensinou"
    static let suggestionNote = "Atividade sugerida: corrida do dia com distância compatível."
    static let useSuggestion = "Usar esta atividade"
    static let openActivity = "Abrir treino"
    static let chooseActivity = "Escolher atividade"
    static let changeActivity = "Trocar atividade"
    static let unlinkActivity = "Desligar atividade"
    static let pickerTitle = "Atividade da prova"
    static let pickerEmpty = "Nenhuma corrida perto do dia da prova."
    static let pickerWindowDays = 3
    static let noActivity = "Nenhuma corrida no dia da prova com distância compatível."
    static let lessonGoalFormat = "Você fechou em %@, %@ da meta"
    static let lessonEveFormat = " e %@ da previsão da véspera"
    static let lessonNoEve = ", sem previsão da véspera para comparar"
    static let lessonSplitsFormat = " Primeira metade a %@/km e segunda a %@/km: %@."
    static let negativeSplit = "split negativo, terminou mais forte"
    static let positiveSplit = "split positivo, o ritmo caiu no fim"
    static let evenSplit = "ritmo constante"
    static let evenSplitTolerance = 2.0
    static let lessonNoResult = "Sem atividade ligada ao resultado, não há o que comparar."
    static let lessonNoGoalFormat = "Você fechou em %@"

    static let editorTitleNew = "Nova prova"
    static let editorTitleEdit = "Editar prova"
    static let fieldName = "Nome"
    static let fieldDate = "Data"
    static let fieldHasStart = "Horário de largada"
    static let fieldStart = "Largada"
    static let fieldDistance = "Distância"
    static let fieldCustomKm = "km"
    static let fieldGoal = "Meta (h:mm:ss)"
    static let fieldPriority = "Prioridade"
    static let fieldCity = "Cidade"
    static let gpxImport = "Importar GPX"
    static let gpxReplace = "Trocar GPX"
    static let gpxRemove = "Remover GPX"
    static let gpxLoaded = "GPX com %d pontos, %@ km"
    static let gpxInvalid = "Não foi possível ler o arquivo GPX."
    static let gpxNoElevation = "O GPX não tem altitude nos pontos."
    static let targetPaceFormat = "Pace alvo %@"
    static let currentPredictionFormat = "previsão %@ · diferença %@"
    static let save = "Salvar"
    static let delete = "Apagar prova"
    static let deleteConfirm = "Apagar esta prova?"
    static let startTimeFormat = "HH:mm"
}
