import Foundation
import Metrics

enum TodayConstants {
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
    static let verdictPhrases: [ReadinessVerdict: String] = [
        .hard: "Pode treinar forte",
        .moderate: "Treino moderado",
        .rest: "Dia de descanso",
    ]
    static let supportStress = "Stress"
    static let rulerRest = "descanso"
    static let rulerModerate = "moderado"
    static let rulerHard = "forte"

    static let fitnessTitleWithRace = "Fitness · até a prova"
    static let fitnessTitleWithoutRace = "Fitness"
    static let fitnessNow = "hoje"
    static let fitnessPeak = "pico"
    static let fitnessRaceForm = "forma no dia"
    static let fitnessLegend = "azul: fitness · amarelo: forma · tracejado: projeção"
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

    static let topRowWeights: [Double] = [3, 2]
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
    static let countdownFontSize: Double = 72
    static let compactCountdownFontSize: Double = 60
    static let daysLabel = "dias"
    static let weekStripHeight: Double = 6
    static let weeksLeftFormat = "%d semanas e %d dias de treino"
    static let raceDayFormLabel = "forma prevista no dia"
    static let bulletHeight: Double = 76
    static let bulletTrackHeight: Double = 10
    static let bulletPaddingRatio = 0.25
    static let bulletMinimumSpan = 120.0
    static let bulletToday = "hoje"
    static let bulletRaceDay = "no dia"
    static let bulletGoal = "meta"
    static let bulletFaster = "mais rápido →"
    static let calendarTitle = "Semana de treino"
    static let calendarRest = "Descanso"
    static let calendarFuture = "—"
    static let calendarCellMinHeight: Double = 122
    static let calendarCompactCellWidth: Double = 116
    static let calendarCornerRadius: Double = 14
    static let calendarDoneTintOpacity = 0.12
    static let calendarDash: [CGFloat] = [4, 3]
    static let calendarDayFormat = "EEE d"
    static let calendarScoreFormat = "nota %d"
    static let calendarSummaryFormat = "%@ km em %d corridas"
    static let zoneStripHeight: Double = 4
    static let volumeTitle = "Volume semanal"
    static let volumeChartHeight: Double = 150
    static let volumeFooterFormat = "esta semana %@ km · média 4 semanas %@ km"
    static let volumeCurrentOpacity = 0.45
    static let volumeAverageLabel = "média 4 sem."
    static let volumeWeekFormat = "d MMM"
    static let predictionsDistance = "distância"
    static let predictionsToday = "hoje"
    static let predictionsYearAgo = "vs. 12 meses"
    static let trendTitle = "Tendência"
}
