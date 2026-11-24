import CoreGraphics
import Foundation
import WorkoutAnalysis

enum WorkoutDetailConstants {
    static let missingValue = "—"
    static let notFoundTitle = "Treino não encontrado"
    static let notFoundText = "Ele pode ter sido apagado ou ainda não chegou neste aparelho."
    static let heartRateFormat = "%d bpm"
    static let similarDistanceTolerance = 0.2
    static let similarRunWindowDays = 90.0
    static let secondsPerDay = 86_400.0
    static let barDomainPadding = 0.08
    static let barMinimumWidth = 0.1
    static let targetDomainPadding = 0.6
    static let maxComparisons = 4
    static let shortLabels = [
        "Aquecimento": "Aquec.",
        "Desaquecimento": "Desaq.",
        "Recuperação": "Recup.",
    ]
    static let repeatLabelPrefix = "Tiro"
    static let blockLabelPrefix = "Bloco"
    static let labelColumnWidth: CGFloat = 76
    static let kilometerIndent: CGFloat = 14
    static let climbFormat = "↑%d m"
    static let descentFormat = "↓%d m"
    static let flatPaceLabel = "no plano"
    static let flatMinimumGap = 2.0
    static let legendTarget = "faixa prescrita"
    static let legendActual = "o que você fez (cor = zona de FC)"
    static let legendFlat = "no plano, descontado o desnível"
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
    static let effectHighZones = "Tempo em Z4–Z5"
    static let effectAerobicShort = "Aeróbico"
    static let effectAnaerobicShort = "Anaeróbico"
    static let effectScale = 5.0
    static let effectNameWidth: CGFloat = 96
    static let effectValueWidth: CGFloat = 34
    static let effectBarHeight: CGFloat = 8
    static let sectionScore = "Nota do treino"
    static let sectionEffect = "Efeito do treino"
    static let sectionPlan = "Planejado × feito"
    static let effectEmpty = "O Garmin não mandou o Training Effect deste treino."
    static let highZoneIndices = [3, 4]
    static let analysisTitle = "Análise"
    static let analysisNegative = "O que foi negativo"
    static let analysisPositive = "O que foi positivo"
    static let analysisExpected = "Dentro do esperado"
    static let analysisNone = "Nenhum"
    static let shareTitle = "Compartilhar"
    static let shareSymbol = "square.and.arrow.up"
    static let actionsTitle = "Ações"
    static let actionsSymbol = "ellipsis.circle"
    static let sectionBlocks = "Blocos × prescrito"
    static let sectionSplits = "Parciais"
    static let sectionHeartRate = "Frequência cardíaca"
    static let sectionZones = "Tempo em zona de FC"
    static let sectionRoute = "Percurso"
    static let sectionGoal = "Meta"
    static let sectionComparison = "Treinos parecidos"
    static let comparisonHeader = "Treino"
    static let structureMissingTitle = "Estrutura do treino ainda não baixada"
    static let structureMissingText = "Os blocos abaixo são os quilômetros do registro. A próxima sincronização baixa a estrutura e refaz a leitura."
    static let recoveryRowPadding = 3.0
    static let rowPadding = 8.0
    static let similarChartPadding = 4.0
    static let similarChartMinimumRuns = 2
    static let similarChartHeight: CGFloat = 130
    static let similarChartAccessibility = "Pace médio dos treinos parecidos, do mais antigo ao atual, com a FC média embaixo"
    static let heartRateColumnWidth: CGFloat = 60
    static let dotColumnWidth: CGFloat = 14
    static let visibleAnalysisEntries = 4
    static let tagColumnWidth: CGFloat = 96
    static let feedbackMaxWidth: CGFloat = 640
    static let tagFix = "Corrigir"
    static let tagGood = "Bom"
    static let tagExpected = "No esperado"
    static let nextTag = "Para o próximo"
    static let showMoreFormat = "Mostrar mais %d"
    static let showLess = "Mostrar menos"
    static let blocksHeaderPace = "pace no alvo · mais rápido →"
    static let blocksHeaderValue = "pace"
    static let blocksHeaderHeartRate = "FC"
    static let windSpeedFormat = "%d km/h"
    static let headwindSymbol = "arrow.down"
    static let tailwindSymbol = "arrow.up"
    static let headwindLabel = "contra"
    static let tailwindLabel = "a favor"
    static let calmPaceLabel = "sem vento"
    static let expectedKinds: Set<FindingKind> = [.blockInTarget, .steadyPace, .climbSlower, .descentFaster, .weatherSlower, .windAgainst, .cardiacDrift]
    static let scoreGaugeSize: Double = 120
    static let aboveExpectedTitle = "Acima do esperado"
    static let aboveExpectedSymbol = "chart.line.uptrend.xyaxis"
    static let aboveExpectedToday = "hoje"
    static let aboveExpectedBeforeFormat = "últimos %d"
    static let aboveExpectedTitles: [AboveExpectedKind: String] = [
        .heartRateAtPace: "FC no mesmo ritmo",
        .recoveryDrop: "Queda de FC na recuperação",
    ]
    static let aboveExpectedUnit = "bpm"
    static let aboveExpectedReplaces: [AboveExpectedKind: FindingKind] = [
        .heartRateAtPace: .lowerHeartRateThanBefore,
        .recoveryDrop: .goodRecovery,
    ]
    static let aboveExpectedLabelWidth: Double = 70
    static let aboveExpectedValueWidth: Double = 58
    static let aboveExpectedBarHeight: Double = 8
    static let aboveExpectedCornerRadius: Double = 16
    static let aboveExpectedBorderWidth: Double = 1.5
    static let aboveExpectedTint = 0.09
    static let compactScoreGaugeSize: Double = 104
    static let scorePartNameWidth: Double = 76
    static let scorePartBarHeight: Double = 8
}
