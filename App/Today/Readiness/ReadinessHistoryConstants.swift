import CoreGraphics

enum ReadinessHistoryConstants {
    static let title = "Últimos 30 dias"
    static let averageShortPrefix = "média 7 dias"
    static let averageLongPrefix = "30 dias"
    static let dayAxis = "Dia"
    static let scoreAxis = "Prontidão"
    static let averageSeries = "Média de 7 dias"
    static let legendHard = "treino forte (70+)"
    static let legendModerate = "moderado (40–69)"
    static let legendRest = "descanso"
    static let averageDays = 7
    static let minimumScores = 2
    static let labelCount = 4
    static let height: CGFloat = 130
    static let barWidthRatio: CGFloat = 0.66
    static let barCorner: CGFloat = 2
    static let pastOpacity = 0.55
    static let averageOpacity = 0.85
    static let averageLineWidth: CGFloat = 1.6
    static let thresholdDash: [CGFloat] = [3, 3]
    static let legendSwatch: CGFloat = 8
}
