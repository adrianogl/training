import Foundation
import Insights

enum EvolutionConstants {
    static let title = "Evolução"
    static let overallTitle = "Estado geral"
    static let verdictBetter = "Melhor que há 3 meses"
    static let verdictStable = "Estável"
    static let verdictWorse = "Pior que há 3 meses"
    static let columnToday = "hoje"
    static let columnDelta = "vs 3 meses"
    static let columnGoal = "vs meta"
    static let windowedToday = "hoje (28 dias)"
    static let predictionPrefix = "Previsão"
    static let emptyValue = "—"
    static let loadingCards = "Calculando as séries…"
    static let endAnchor = "evolucao-fim"
    static let metricsAnchor = "evolucao-metricas"
    static let groupStorageKey = "evolucao-grupo"
    static let gridMinimumWidth: Double = 160
    static let featuredChartHeight: Double = 120
    static let compactPointLimit = 90
    static let detailChartHeight: Double = 240
    static let monthlyChartHeight: Double = 120
    static let monthlyBars = 12
    static let heatmapWeeks = HeatmapDefaults.weeks
    static let heatmapTitle = "Atividades"
    static let heatmapCellSpacing: Double = 2
    static let heatmapLegend = "km por dia nas últimas 26 semanas"
    static let heatmapMinimumOpacity = 0.25
    static let defaultPeriod = MetricPeriod.oneYear
    static let minusSign = "\u{2212}"

    static let summaryTitle = "Resumo do período"
    static let overallWindow = "vs. 3 meses atrás"
    static let historyTitle = "Histórico"
    static let indicatorValueWidth: Double = 76
    static let indicatorDeltaWidth: Double = 58
    static let indicatorGoalWidth: Double = 60
    static let lowerIsBetterIndicators: Set<IndicatorKind> = [.racePrediction, .zone2Pace, .thresholdPace]
    static let metricsTitle = "Métricas"
    static let sparklineHeight: Double = 24
    static let monthlyBarHeight: Double = 56
    static let predictionsGroupTitle = "Previsões"
    static let recordBeatFormat = "★ %@ abaixo do RP %@"
    static let recordAboveFormat = "%@ acima do RP %@"
    static let recordEqualFormat = "igual ao RP %@"
    static let recordMissing = "sem RP ainda"
    static let metricGroups: [MetricGroup] = [
        MetricGroup(title: "Ritmo e limiar", kinds: [.thresholdPace, .zone2Pace, .thresholdHeartRate]),
        MetricGroup(title: "Capacidade", kinds: [.vo2max, .fitness, .hillStrength, .durability]),
        MetricGroup(title: "Volume e carga", kinds: [.monthlyVolume, .loadFocus, .zoneDistribution]),
        MetricGroup(title: "Recuperação", kinds: [.restingHeartRate, .hrv, .sleep, .bodyBattery]),
        MetricGroup(title: "Técnica de corrida", kinds: [.cadence, .groundContact, .verticalOscillation]),
        MetricGroup(title: predictionsGroupTitle, kinds: MetricKind.predictionKinds),
    ]
    static let groupChipSpacing: Double = 6
    static let heatmapWeekdayLabels = ["S", "", "Q", "", "S", "", "D"]
    static let heatmapLabelWidth: Double = 14
    static let heatmapWeekdayFontSize: Double = 10
    static let heatmapMonthFormat = "MMM"
    static let heatmapTotalFormat = "%@ km · 26 semanas"
    static let periodSuffix = " no período"
    static let noChange = "sem mudança"
    static let heatmapLess = "menos"
    static let heatmapMore = "mais"
    static let heatmapScaleSteps = [0.0, 0.3, 0.55, 0.8, 1.0]
    static let heatmapScaleCell: Double = 10

    static let periodTitles: [MetricPeriod: String] = [
        .sixMonths: "6M", .oneYear: "1 ano", .twoYears: "2 anos", .all: "Tudo",
    ]
    static let periodDays: [MetricPeriod: Int] = [.sixMonths: 182, .oneYear: 365, .twoYears: 730]
    static let periodLabel = "Período"
    static let periodPickerWidth: Double = 320

    static let cardKinds: [MetricKind] = [
        .vo2max, .zone2Pace, .fitness, .monthlyVolume, .loadFocus, .thresholdPace, .thresholdHeartRate,
        .prediction1k, .prediction3k, .prediction5k, .prediction10k, .predictionHalf, .predictionFull,
        .durability, .hillStrength, .cadence, .groundContact, .verticalOscillation,
        .restingHeartRate, .hrv, .sleep, .bodyBattery, .zoneDistribution,
    ]

    static let metricNames: [MetricKind: String] = [
        .vo2max: "VO2max",
        .zone2Pace: "Pace na Z2",
        .fitness: "Fitness",
        .monthlyVolume: "Volume mensal",
        .loadFocus: "Carga aeróbica leve",
        .thresholdPace: "Pace de limiar",
        .thresholdHeartRate: "FC de limiar",
        .prediction1k: "Previsão de 1 km",
        .prediction3k: "Previsão de 3 km",
        .prediction5k: "Previsão de 5 km",
        .prediction10k: "Previsão de 10 km",
        .predictionHalf: "Previsão da meia maratona",
        .predictionFull: "Previsão da maratona",
        .durability: "Durabilidade",
        .hillStrength: "Força em subida",
        .cadence: "Cadência",
        .groundContact: "Contato com o solo",
        .verticalOscillation: "Oscilação vertical",
        .restingHeartRate: "FC de repouso",
        .hrv: "HRV",
        .sleep: "Nota do sono",
        .bodyBattery: "Body Battery",
        .zoneDistribution: "Tempo em Z1 e Z2",
    ]

    static let metricFormats: [MetricKind: MetricValueFormat] = [
        .vo2max: .number(decimals: 1, unit: ""),
        .zone2Pace: .pace,
        .fitness: .number(decimals: 0, unit: ""),
        .monthlyVolume: .number(decimals: 0, unit: " km"),
        .loadFocus: .number(decimals: 0, unit: "%"),
        .thresholdPace: .pace,
        .thresholdHeartRate: .number(decimals: 0, unit: " bpm"),
        .prediction1k: .duration,
        .prediction3k: .duration,
        .prediction5k: .duration,
        .prediction10k: .duration,
        .predictionHalf: .duration,
        .predictionFull: .duration,
        .durability: .number(decimals: 1, unit: "%"),
        .hillStrength: .number(decimals: 0, unit: ""),
        .cadence: .number(decimals: 0, unit: " spm"),
        .groundContact: .number(decimals: 0, unit: " ms"),
        .verticalOscillation: .number(decimals: 1, unit: " cm"),
        .restingHeartRate: .number(decimals: 0, unit: " bpm"),
        .hrv: .number(decimals: 0, unit: " ms"),
        .sleep: .number(decimals: 0, unit: ""),
        .bodyBattery: .number(decimals: 0, unit: ""),
        .zoneDistribution: .number(decimals: 0, unit: "%"),
    ]

    static let indicatorFormats: [IndicatorKind: MetricValueFormat] = [
        .racePrediction: .duration,
        .vo2max: .number(decimals: 1, unit: ""),
        .fitness: .number(decimals: 0, unit: ""),
        .zone2Pace: .pace,
        .thresholdPace: .pace,
        .monthlyVolume: .number(decimals: 0, unit: " km"),
    ]
    static let windowedIndicators: Set<IndicatorKind> = [.zone2Pace, .thresholdPace]

    static let lowerIsBetter: Set<MetricKind> = [
        .zone2Pace, .thresholdPace, .prediction1k, .prediction3k, .prediction5k, .prediction10k, .predictionHalf, .predictionFull,
        .restingHeartRate, .durability, .groundContact, .verticalOscillation,
    ]
    static let higherIsBetter: Set<MetricKind> = [
        .vo2max, .fitness, .monthlyVolume, .hillStrength, .hrv, .sleep, .bodyBattery, .zoneDistribution,
    ]
    static let reversedAxis: Set<MetricKind> = [
        .zone2Pace, .thresholdPace, .prediction1k, .prediction3k, .prediction5k, .prediction10k, .predictionHalf, .predictionFull,
    ]

    static let detailCurrent = "Atual"
    static let detailAverage = "Média"
    static let detailMinimum = "Mínimo"
    static let detailMaximum = "Máximo"
    static let detailTrend = "Tendência"
    static let detailRaceDay = "No dia da prova"
    static let detailChartTitle = "Gráfico"
    static let raceLegend = "prova"
    static let raceMarkerFormat = "%@ · %@"
    static let detailMonthly = "Médias mensais"
    static let detailLastYear = "Mesmo período do ano anterior"
    static let detailLastYearFormat = "média de %@ há 12 meses (%@ de diferença)"
    static let detailNoDataTitle = "Sem dados suficientes"
    static let detailNoData = "Ainda não há dados desta métrica no período escolhido."
    static let detailNoDataSymbol = "chart.xyaxis.line"
    static let dailyLabel = "Diário"
    static let averageLabel = "média de 7 dias"
    static let projectionLabel = "projeção"
    static let lastYearLabel = "ano anterior"
}
