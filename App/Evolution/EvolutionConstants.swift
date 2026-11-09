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
    static let tableLegend = "verde = melhorou · amarelo = piorou ou falta chegar"
    static let windowedFootnote = "Nos paces, \"hoje (28 dias)\" é a mediana dos últimos 28 dias. O card do pace mostra o valor do último treino."
    static let predictionPrefix = "Previsão"
    static let emptyValue = "—"
    static let cardsTitle = "Métricas"
    static let loadingCards = "Calculando as séries…"
    static let endAnchor = "evolucao-fim"
    static let highlightAnchor = "evolucao-destaque"
    static let gridMinimumWidth: Double = 160
    static let cardChartHeight: Double = 44
    static let compactPointLimit = 90
    static let detailChartHeight: Double = 240
    static let monthlyChartHeight: Double = 120
    static let monthlyBars = 12
    static let horizonCapDays = 60
    static let heatmapWeeks = HeatmapDefaults.weeks
    static let heatmapTitle = "Atividades"
    static let heatmapCellSpacing: Double = 2
    static let heatmapLegend = "km por dia nas últimas 26 semanas"
    static let heatmapMinimumOpacity = 0.25
    static let defaultPeriod = MetricPeriod.oneYear
    static let minusSign = "\u{2212}"

    static let periodTitles: [MetricPeriod: String] = [
        .sixMonths: "6M", .oneYear: "1 ano", .twoYears: "2 anos", .all: "Tudo",
    ]
    static let periodDays: [MetricPeriod: Int] = [.sixMonths: 182, .oneYear: 365, .twoYears: 730]
    static let horizonTitles: [ProjectionHorizon: String] = [
        .untilRace: "Até a prova", .sixMonths: "6 meses", .oneYear: "1 ano",
    ]
    static let horizonDays: [ProjectionHorizon: Int] = [.sixMonths: 182, .oneYear: 365]
    static let periodLabel = "Período"
    static let horizonLabel = "Projeção"

    static let cardKinds: [MetricKind] = [
        .vo2max, .zone2Pace, .fitness, .monthlyVolume, .loadFocus, .thresholdPace, .thresholdHeartRate,
        .prediction5k, .prediction10k, .predictionHalf, .predictionFull,
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
        .prediction5k: "Previsão de 5 km",
        .prediction10k: "Previsão de 10 km",
        .predictionHalf: "Previsão de 21,1 km",
        .predictionFull: "Previsão de 42,2 km",
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
        .zone2Pace, .thresholdPace, .prediction5k, .prediction10k, .predictionHalf, .predictionFull,
        .restingHeartRate, .durability, .groundContact, .verticalOscillation,
    ]
    static let higherIsBetter: Set<MetricKind> = [
        .vo2max, .fitness, .monthlyVolume, .hillStrength, .hrv, .sleep, .bodyBattery, .zoneDistribution,
    ]
    static let reversedAxis: Set<MetricKind> = [
        .zone2Pace, .thresholdPace, .prediction5k, .prediction10k, .predictionHalf, .predictionFull,
    ]

    static let detailCurrent = "Atual"
    static let detailAverage = "Média"
    static let detailMinimum = "Mínimo"
    static let detailMaximum = "Máximo"
    static let detailTrend = "Tendência"
    static let detailRaceDay = "No dia da prova"
    static let detailReading = "Leitura"
    static let detailMonthly = "Médias mensais"
    static let detailLastYear = "Mesmo período do ano anterior"
    static let detailLastYearFormat = "média de %@ há 12 meses (%@ de diferença)"
    static let detailLegend = "branco: média de 7 dias · tracejado: projeção · cinza: ano anterior"
    static let detailNoData = "Sem dados suficientes para esta métrica."
    static let dailyLabel = "Diário"
    static let averageLabel = "Média 7 dias"
    static let projectionLabel = "Projeção"
    static let lastYearLabel = "Ano anterior"
}
