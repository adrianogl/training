import Storage

enum InsightsConstants {
    static let rawNormalWindowDays = 30
    static let rawNormalMinimumDays = 14
    static let defaultRaceDistance = 21_097.5
    static let yearDays = 365
    static let effortWindowDays = 150
    static let raceEffortWindowDays = 365
    static let predictionChunkDays = 30
    static let raceHistoryDays = yearDays + raceEffortWindowDays
    static let goalHorizonDays = 365
    static let raceProjectionFallbackDays = 60
    static let metricProjectionDays = 60
    static let readinessHistoryDays = 30
    static let comparisonDays = 90
    static let paceWindowDays = 28
    static let volumeWindowDays = 30
    static let focusWindowDays = 28
    static let movingAverageDays = 7
    static let previousWeeks = 4
    static let volumeHistoryWeeks = 8
    static let daysPerWeek = 7
    static let metersPerKm = 1_000.0
    static let verdictDifference = 2
    static let stableFraction = 0.01
    static let lowZoneCount = 2
    static let zoneCount = 5
    static let percent = 100.0
    static let noDataReading = "Sem dados suficientes para esta métrica."
    static let distanceLabels: [Double: String] = [
        5_000: "5 km",
        10_000: "10 km",
        21_097.5: "21,1 km",
        42_195: "42,2 km",
    ]
    static let periodDays: [MetricPeriod: Int] = [.sixMonths: 182, .oneYear: 365, .twoYears: 730]
    static let predictionDistances: [MetricKind: Double] = [
        .prediction5k: 5_000,
        .prediction10k: 10_000,
        .predictionHalf: 21_097.5,
        .predictionFull: 42_195,
    ]
    static let lowerIsBetter: Set<IndicatorKind> = [.racePrediction, .zone2Pace, .thresholdPace]
    static let margins: [IndicatorKind: IndicatorMargin] = [
        .racePrediction: IndicatorMargin(value: 0.005, relative: true),
        .vo2max: IndicatorMargin(value: 0.5, relative: false),
        .fitness: IndicatorMargin(value: 2, relative: false),
        .zone2Pace: IndicatorMargin(value: 3, relative: false),
        .thresholdPace: IndicatorMargin(value: 3, relative: false),
        .monthlyVolume: IndicatorMargin(value: 0.10, relative: true),
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
        .durability: "Desacoplamento",
        .hillStrength: "Força em subida",
        .cadence: "Cadência",
        .groundContact: "Contato com o solo",
        .verticalOscillation: "Oscilação vertical",
        .restingHeartRate: "FC de repouso",
        .hrv: "HRV",
        .sleep: "Sono",
        .bodyBattery: "Body Battery",
        .zoneDistribution: "Tempo em Z1 e Z2",
    ]
    static let metricFormats: [MetricKind: MetricFormat] = [
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
    static let kmSuffix = " km"
    static let rose = "subiu"
    static let fell = "caiu"
    static let steady = "ficou estável"
}
