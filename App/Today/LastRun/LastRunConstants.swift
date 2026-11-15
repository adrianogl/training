enum LastRunConstants {
    static let windowDays = 60.0
    static let maxSimilar = 3
    static let secondsPerDay = 86_400.0
    static let heartRateHighDelta = 8.0
    static let paceSameSeconds = 5.0
    static let heartRateSameDelta = 3.0
    static let readinessLow = 50
    static let climbShown = 150.0
    static let minutesPerHour = 60
    static let planGood = 0.9
    static let chartHeight: Double = 64
    static let chartPaddingRatio = 0.05
    static let zonesHeight: Double = 6
    static let rowDistanceWidth: Double = 130
    static let rowPaceWidth: Double = 48
    static let rowHeartRateWidth: Double = 36
    static let secondsPerMinute = 60.0
    static let dateFormat = "EEE d/M"
    static let shortDateFormat = "d/M"

    static let viewAnalysis = "Ver análise ›"
    static let compactTitleFormat = "%@ · %@ km"
    static let compactHeartRateFormat = "FC %d"
    static let compactPlanFormat = "%d%% do plano"
    static let compactReadingLines = 2
    static let minutesFormat = "%d min"
    static let hoursMinutesFormat = "%dh%02d"
    static let planFormat = "plano %@ km"
    static let percentFormat = "%d%%"
    static let kmLabel = "km"
    static let paceLabel = "pace /km"
    static let heartRateLabel = "FC média"
    static let climbLabel = "subida"
    static let climbFormat = "%d m"
    static let chartLegendPace = "pace por km"
    static let chartLegendHeartRate = "FC"
    static let fadeFormat = "queda no km %d"
    static let noSimilarFormat = "Sem outros treinos de %@ nos últimos 60 dias."
    static let rowFormat = "%@ km"
    static let rowClimbFormat = "%@ km · +%d m"

    static let kindTitles: [SessionKind: String] = [.long: "Longão", .threshold: "Limiar", .intervals: "VO2 máx", .easy: "Rodagem", .race: "Prova"]
    static let recentTitles: [SessionKind: String] = [
        .long: "Longões recentes", .threshold: "Limiares recentes", .intervals: "VO2 máx recentes", .easy: "Rodagens recentes", .race: "Provas recentes",
    ]
    static let kindNames: [SessionKind: String] = [.long: "longão", .threshold: "limiar", .intervals: "VO2 máx", .easy: "rodagem", .race: "prova"]

    static let samePaceFormat = "Mesmo pace do %@ de %@"
    static let fasterFormat = "Pace %d s/km mais rápido que o %@ de %@"
    static let slowerFormat = "Pace %d s/km mais lento que o %@ de %@"
    static let heartRateHigher = ", com a FC %d bpm mais alta"
    static let heartRateLower = ", com a FC %d bpm mais baixa"
    static let heartRateSame = ", com FC parecida"
    static let fadeReading = " e queda a partir do km %d"
    static let readinessFormat = " A prontidão do dia era %d."
}
