import OSLog
import GarminAPI
import Foundation
import Metrics

enum TodayConstants {
    static let logger = Logger(subsystem: "trAIning", category: "Today")
    static let moderateThreshold = 40
    static let hardThreshold = 70
    static let fitnessHistoryDays = 60
    static let predictionHistoryDays = 120
    static let endAnchor = "hoje-fim"
    static let comparisonWindowDays = 90.0
    static let comparisonFetchLimit = 120
    static let factorBarFullScale = 10.0
    static let chartHeight: Double = 90
    static let predictionChartHeight: Double = 120
    static let months = [
        "janeiro", "fevereiro", "março", "abril", "maio", "junho",
        "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
    ]
    static let earlyMonthLimit = 10
    static let midMonthLimit = 20
    static let daysPerWeek = 7.0
    static let predictionLabels = ["5 km", "10 km", "21,1 km", "42,2 km"]
    static let minusSign = "\u{2212}"
    static let ratioFormat = "%.2f"

    static let todayTitle = "Hoje"
    static let readinessTitle = "Prontidão"
    static let readinessEmpty = "Sem dados de recuperação de hoje."
    static let yesterdayBannerPadding: CGFloat = 8
    static let yesterdayBannerOpacity = 0.14
    static let readinessFromYesterday = "De ontem · a de hoje sai quando você acordar"
    static let garminReadinessNote = "Nota da Garmin. Sem o sono e o HRV desta noite, o app não calculou a própria."
    static let verdictPhrases: [ReadinessVerdict: String] = [
        .hard: "Pode treinar forte",
        .moderate: "Treino moderado",
        .rest: "Dia de descanso",
    ]
    static let supportStress = "Stress"
    static let rulerRest = "descanso"
    static let rulerModerate = "moderado"
    static let rulerHard = "forte"

    static let fitnessNow = "hoje"
    static let fitnessPeak = "pico"
    static let fitnessEmpty = "Ainda sem treinos com carga para calcular o fitness."

    static let predictionTitle = "Previsão"
    static let predictionToday = "Hoje"
    static let predictionRaceDay = "No dia da prova"
    static let predictionEmpty = "Ainda sem esforços suficientes para prever."
    static let predictionBandPrefix = "faixa"
    static let predictionYearAgoPrefix = "há 12 meses"
    static let goalPrefix = "meta"
    static let goalOn = "Meta de %@ deve chegar em %@ de %@%@."
    static let goalAfterRace = ", %d %@ depois da prova"
    static let goalBeaten = "A previsão já está abaixo da meta."
    static let goalUnreachable = "Na tendência atual, a meta não é alcançada."

    static let predictionsTitle = "Previsões"
    static let lastRunTitle = "Último treino"
    static let lastRunNoComparison = "Sem treinos parecidos para comparar."
    static let lastRunDistance = "distância"
    static let lastRunPace = "pace"
    static let lastRunHeartRate = "FC média"
    static let fitnessLegendFitness = "fitness"
    static let fitnessLegendForm = "forma"
    static let fitnessLegendProjection = "tracejado: projeção"
    static let fitnessLegendRace = "prova"
    static let legendSwatchWidth: Double = 14
    static let legendSwatchHeight: Double = 3

    static let detailTitle = "Prontidão"
    static let detailUp = "Puxando para cima"
    static let detailDown = "Puxando para baixo"
    static let detailNoBaseline = "Valor do dia"
    static let detailMissing = "Sem dado"
    static let detailMissingValue = "sem dado"
    static let detailStressContext = "Stress do dia aparece como contexto, mas não entra na nota."
    static let detailExplanationTitle = "Como os pontos são calculados"
    static let detailExplanation = "A prontidão é a média ponderada de quatro notas de 0 a 100: HRV (35%), sono (25%), Body Battery (20%) e carga aguda:crônica (20%). Cada fator mostra quanto empurra a nota de hoje em relação ao seu normal dos últimos 30 dias: peso × (nota do fator hoje − média de 30 dias da nota do fator). O veredito vem dos limites fixos de 40 e 70. O normal só vale a partir de 14 dias com dado nos últimos 30."
    static let detailNoNormal = "Ainda sem normal de 30 dias para comparar."
    static let loadIdealRange = "ideal 0,8–1,3"

    static let componentNames: [ReadinessComponent: String] = [
        .hrv: "HRV da noite",
        .sleep: "Sono",
        .bodyBattery: "Body Battery ao acordar",
        .load: "Carga da semana",
    ]

    static let sidebarRaceTitle = "Prova-alvo"

    static let overloadTintOpacity = 0.12
    static let rowSpacing: Double = 12
    static let heroGaugeSize: Double = 150
    static let compactGaugeSize: Double = 112
    static let gaugeLineWidth: Double = 12
    static let gaugeSweep = 0.75
    static let gaugeStartDegrees = 135.0
    static let gaugeGap = 0.006
    static let gaugeTrackOpacity = 0.25
    static let gaugeMarkerSize: Double = 16
    static let gaugeScoreRatio = 0.34
    static let gaugeScale = "de 100"
    static let driverNameWidth: Double = 112
    static let driverValueWidth: Double = 44
    static let driverBarHeight: Double = 8
    static let driverScaleMinimum = 10.0
    static let driverDown = "puxa para baixo"
    static let driverUp = "puxa para cima"
    static let stressContextFormat = "Stress do dia %d · entra só como contexto"
    static let compactCountdownFontSize: Double = 60
    static let daysLabel = "dias"
    static let weeksLeftJoin = " e "
    static let weeksLeftSuffix = " de treino"
    static let weekSingular = "semana"
    static let weekPlural = "semanas"
    static let daySingular = "dia"
    static let dayPlural = "dias"
    static let bulletPaddingRatio = 0.25
    static let bulletToday = "hoje"
    static let bulletRaceDay = "no dia"
    static let bulletGoal = "meta"
    static let bulletAnd = "e"
    static let bulletLabelInset = 32.0
    static let bulletLabelGap = 64.0
    static let bulletRulerHeight: Double = 104
    static let bulletRulerTrackY = 44.0
    static let bulletAboveY = 12.0
    static let bulletBelowY = 90.0
    static let bulletTickHeight = 16.0
    static let bulletTickLabelY = 62.0
    static let bulletTickGoalGap = 24.0
    static let bulletRulerSpan = 30.0
    static let bulletMaximumTicks = 4
    static let bulletTickSteps: [Double] = [5, 10, 15, 30, 60, 120, 180, 300, 600, 900, 1_800]
    static let bulletGoalReached = "na meta no dia"
    static let bulletGapBehind = "faltam %@ no dia"
    static let bulletGapAhead = "%@ abaixo da meta no dia"
    static let calendarDash: [CGFloat] = [4, 3]
    static let zoneStripHeight: Double = 4
    static let volumeTitle = "Volume semanal"
    static let volumeChartHeight: Double = 190
    static let volumeThisWeek = "esta semana"
    static let volumeClosesFormat = "esta semana · fecha em ~%@"
    static let volumeAverageCaption = "média 4 semanas"
    static let volumeAdherenceCaption = "aderência nas semanas fechadas"
    static let volumeKmFormat = "%@ km"
    static let volumeLegendDone = "realizado"
    static let volumeLegendPlanned = "planejado"
    static let volumeLegendBelow = "abaixo do plano"
    static let volumePercentGood = 0.8
    static let volumeGapOpacity = 0.28
    static let volumeLineWidth = 2.5
    static let volumeHeadroom = 1.15
    static let volumePointSize: Double = 45
    static let volumePlannedPointSize: Double = 14
    static let volumeProjectionOpacity = 0.45
    static let volumeAxisLabelSpacing: Double = 2
    static let volumeAccessibilityFormat = "%@: %@ km realizados, %@ km planejados, %d%%"
    static let volumeAverageLabel = "média 4 sem."
    static let volumeGoalLabel = "meta"
    static let volumeTitlePlanned = "Volume semanal · planejado × realizado"
    static let adherenceGood = 0.95
    static let adherenceFormat = "%d%%"
    static let volumeWeekFormat = "d MMM"
    static let blockLabelTopInset: Double = 20
    static let blockLabelBottomInset: Double = 4
    static let blockNow = "Como estou"
    static let blockToday = "O que faço hoje"
    static let blockWeek = "Como vai a semana"
    static let blockOutlook = "Onde vou chegar"
    static let outlookPredictionLabels = ["5 km", "10 km", "21,1 km"]
    static let outlookRaceFormat = "Prova-alvo · %@"
    static let outlookGoalTodayFormat = "hoje %@"
    static let outlookLongRunsFormat = "%d de %d longões"
    static let outlookFitnessTitle = "Forma até a prova"
    static let outlookFitnessFormat = "%@ no dia"
    static let outlookDividerPadding: Double = 2
    static let planTitle = "Treino de hoje"
    static let workoutSourceGarmin = "Garmin"
    static let workoutSourceTrainer = "seu treinador"
    static let workoutTitleFormat = "%@ · %@"
    static let workoutTomorrow = "amanhã"
    static let workoutTomorrowPrefix = "Amanhã"
    static let workoutNothingTomorrow = "Nada planejado para amanhã."
    static let workoutReadinessFormat = "prontidão %d"
    static let workoutBestTimeTitle = "Melhor horário amanhã"
    static let planEstimateFormat = "%@ km · ~%@"
    static let planStepNames: [PlannedStepKind: String] = [
        .warmup: "Aquecimento", .active: "Bloco", .recovery: "Recuperação", .cooldown: "Desaquecimento", .rest: "Descanso", .other: "Passo",
    ]
    static let planRepeatFormat = "%d×"
    static let planZoneFormat = "Z%d"
    static let planHeartRateFormat = "%d–%d bpm"
    static let planMinutesFormat = "%d min"
    static let planMetersFormat = "%d m"
    static let planShapeHeight: Double = 40
    static let planShapeDefaultPace = 330.0
    static let planShapeLevels: [PlannedStepKind: Int] = [.warmup: 2, .active: 4, .recovery: 1, .cooldown: 1, .rest: 1, .other: 2]
    static let planAdjustTitle = "Ajuste para hoje"
    static let planAdjust: [ReadinessVerdict: String] = [
        .hard: "Prontidão boa: siga o plano como está.",
        .moderate: "Prontidão moderada: faça os blocos fortes no lado mais lento da faixa e pare um bloco antes se a FC subir demais.",
        .rest: "Prontidão baixa: troque por rodagem leve em Z1–Z2 ou descanse hoje.",
    ]
}
