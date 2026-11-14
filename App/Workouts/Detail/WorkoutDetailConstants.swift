import CoreGraphics
import Foundation
import WorkoutAnalysis

enum WorkoutDetailConstants {
    static let similarDistanceTolerance = 0.2
    static let similarRunWindowDays = 90.0
    static let secondsPerDay = 86_400.0
    static let barDomainPadding = 0.08
    static let barMinimumWidth = 0.1
    static let targetDomainPadding = 0.6
    static let maxComparisons = 4
    static let similarRunsTitle = "Distância parecida"
    static let shortLabels = [
        "Aquecimento": "Aquec.",
        "Desaquecimento": "Desaq.",
        "Recuperação": "Recup.",
    ]
    static let labelColumnWidth: CGFloat = 76
    static let kilometerIndent: CGFloat = 14
    static let valueColumnWidth: CGFloat = 52
    static let barHeight: CGFloat = 8
    static let bandHeight: CGFloat = 14
    static let comparisonValueWidth: CGFloat = 58
    static let maxChartPoints = 600
    static let secondsPerMinute = 60.0
    static let heartRateDomainPadding = 5.0
    static let altitudeDomainPadding = 3.0
    static let routeFramePadding = 0.18
    static let routeMinimumSpan = 400.0
    static let mapHeight: CGFloat = 220
    static let altitudeHeight: CGFloat = 64
    static let heartRateChartHeight: CGFloat = 200
    static let routeLineWidth: CGFloat = 3.5
    static let routeMarkerSize: CGFloat = 12
    static let zoneBarHeight: CGFloat = 12
    static let zoneBandOpacity = 0.12
    static let activeBlockOpacity = 0.09
    static let altitudeFillOpacity = 0.25
    static let zoneCount = 5
    static let onDeviceCaption = "texto gerado no aparelho"
    static let rulerRange = 100...180
    static let rulerTopMargin = 10
    static let rulerBarHeight: CGFloat = 16
    static let rulerBarCornerRadius: CGFloat = 6
    static let rulerTickHeight: CGFloat = 5
    static let rulerScaleHeight: CGFloat = 22
    static let rulerWatchTitle = "Relógio (Garmin)"
    static let rulerThresholdTitle = "Pelo limiar (%d bpm)"
    static let rulerMissingThreshold = "sem FC de limiar no Garmin"
    static let rulerDivergenceBelow = "Zonas do relógio %d bpm abaixo do limiar"
    static let rulerDivergenceAbove = "Zonas do relógio %d bpm acima do limiar"
    static let rulerTimeSeparator = " · "

    static let effectTitle = "Efeito esperado do treino"
    static let effectFallback = "Efeito do treino"
    static let effectLabels: [String: String] = [
        "AEROBIC_BASE": "Base aeróbica",
        "TEMPO": "Tempo",
        "LACTATE_THRESHOLD": "Limiar de lactato",
        "VO2MAX": "Estímulo de VO2máx.",
        "ANAEROBIC_CAPACITY": "Capacidade anaeróbica",
        "SPEED": "Velocidade",
        "RECOVERY": "Recuperação",
    ]
    static let effectLevels = ["sem efeito", "efeito pequeno", "manutenção", "melhora", "grande melhora", "excessivo"]
    static let effectAerobic = "Training Effect aeróbico"
    static let effectAnaerobic = "Training Effect anaeróbico"
    static let effectHighZones = "Tempo em Z4–Z5"
    static let effectLoad = "Carga do treino"
    static let effectSentenceFormat = "Efeito aeróbico %@ (%@) e anaeróbico %@ (%@)."
    static let effectEmpty = "O Garmin não mandou o Training Effect deste treino."
    static let highZoneIndices = [3, 4]
    static let analysisTitle = "Análise"
    static let analysisNegative = "O que foi negativo"
    static let analysisPositive = "O que foi positivo"
    static let analysisExpected = "Dentro do esperado"
    static let analysisNone = "Nenhum"
    static let shareTitle = "Compartilhar"
    static let shareSymbol = "square.and.arrow.up"
    static let negativeMarker = "N"
    static let positiveMarker = "P"
    static let heartRateColumnWidth: CGFloat = 60
    static let markerColumnWidth: CGFloat = 30
    static let blocksHeaderPace = "pace no alvo · mais rápido →"
    static let blocksHeaderValue = "pace"
    static let blocksHeaderHeartRate = "FC"
    static let blocksMarkerNote = "As marcas N e P apontam para os itens da análise."
    static let expectedKinds: Set<FindingKind> = [.blockInTarget, .steadyPace]
    static let scoreGaugeSize: Double = 120
    static let compactScoreGaugeSize: Double = 104
    static let scorePartNameWidth: Double = 76
    static let scorePartBarHeight: Double = 8
    static let pairWeights: [Double] = [1, 1]
}
