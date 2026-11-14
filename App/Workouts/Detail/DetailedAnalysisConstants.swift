import CoreGraphics

enum GeneratedTextConstants {
    static let keyPrefix = "generatedText."
}

enum DetailedScreenConstants {
    static let coachTimeoutSeconds = 8.0
    static let generatingLabel = "Gerando no aparelho"
    static let skeletonWidths: [CGFloat] = [1, 0.94, 0.97, 0.58]
    static let skeletonLineHeight: CGFloat = 12
    static let skeletonLineSpacing: CGFloat = 8
    static let pulseDotSize: CGFloat = 7
    static let pulseSeconds = 1.2
    static let pulseLowOpacity = 0.3
    static let buttonTitle = "Ver análise detalhada"
    static let screenTitle = "Análise detalhada"
    static let comparedFormat = "comparado com %d treinos dos últimos %d dias"
    static let noSimilar = "sem treinos parecidos nos últimos %d dias"
    static let unavailable = "Este treino não tem o registro km a km para analisar."
    static let kmTitle = "Este treino km a km"
    static let similarTitle = "Contra os treinos parecidos"
    static let findingsTitle = "Padrões encontrados"
    static let recommendationsTitle = "Recomendações"
    static let coachTitle = "Texto do treinador"
    static let paceLegend = "pace (mais rápido em cima)"
    static let heartRateLegend = "FC (bpm)"
    static let fadeLabelFormat = "queda a partir do km %d"
    static let pauseLabel = "pausa"
    static let legendClean = "completo e sem pausas"
    static let legendComplete = "completo"
    static let legendPartial = "incompleto"
    static let legendToday = "hoje"
    static let sourcesFormat = "Fontes: %d treinos parecidos e %d dias de prontidão dos últimos %d dias."
    static let kpiCompletionPlanned = "da distância planejada"
    static let kpiCompletionReference = "da distância típica dos parecidos"
    static let kpiFade = "início da queda de pace"
    static let kpiNoFade = "sem queda de pace"
    static let kpiDrift = "deriva da FC"
    static let averageFormat = "média %@"
    static let kmFormat = "km %d"
    static let chartHeight: CGFloat = 130
    static let heartRateChartHeight: CGFloat = 90
    static let similarChartHeight: CGFloat = 120
    static let lineWidth: CGFloat = 2.2
    static let ruleDash: [CGFloat] = [3, 3]
    static let ruleOpacity = 0.6
    static let partialOpacity = 0.35
    static let barCornerRadius: CGFloat = 3
    static let glyphSize: CGFloat = 22
    static let badgeSize: CGFloat = 20
    static let columnWeights: [Double] = [1, 1]
    static let contentMaxWidth: CGFloat = 640
    static let fixSymbol = "exclamationmark"
    static let goodSymbol = "arrow.up.right"
    static let infoSymbol = "equal"
    static let chartAccessibility = "Pace e frequência cardíaca por quilômetro"
    static let similarAccessibility = "Percentual da distância feita nos treinos parecidos e hoje"
}
