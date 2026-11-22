import CoreGraphics
import WorkoutAnalysis

enum ScoreConstants {
    static let badgeCaption = "nota"
    static let breakdownTitle = "Nota do treino"
    static let excludedSuffix = "fora da nota"
    static let strongThreshold = 80
    static let moderateThreshold = 60
    static let detailBadgeSize: CGFloat = 56
    static let rowInlineSize: CGFloat = 20
    static let cardBadgeSize: CGFloat = 34
    static let perfectScore = 100
    static let perfectTitle = "Treino perfeito"
    static let perfectAccessibility = "treino perfeito"
    static let perfectSymbol = "star.fill"
    static let perfectSymbolSize: CGFloat = 12
    static let perfectInlineSize: CGFloat = 17
    static let perfectCaption = "perfeito"
    static let perfectBadgeRatio: CGFloat = 0.76
    static let perfectSymbolRatio: CGFloat = 0.44
    static let perfectBorderWidth: CGFloat = 1.5
    static let perfectGlowHeight = 0.7
    static let shineDuration = 1.1
    static let shineWidth = 0.3
    static let shineOpacity = 0.35
    static let shineAngle = 15.0
    static let fillDuration = 1.1
    static let rippleDuration = 1.2
    static let rippleSecondDelay = 0.25
    static let rippleScale: CGFloat = 2.1
    static let rippleOpacity = 0.8
    static let rippleLineWidth: CGFloat = 3
    static let celebratedRowsKey = "scoreCelebratedRows"
    static let celebratedDetailsKey = "scoreCelebratedDetails"
    static let celebrationMemory = 400
    static let perfectLineAllTargets = "Tudo no alvo e mais eficiente que nos treinos iguais"
    static let perfectLineBlockSingular = "bloco"
    static let perfectLineBlockPlural = "blocos"
    static let perfectLineSuffix = "no alvo e mais eficiente que nos treinos iguais"
    static let partNames: [ScorePart: String] = [
        .execution: "Execução",
        .intent: "Intenção",
        .cost: "Custo",
    ]
    static let reasonTexts: [ScoreReason: String] = [
        .blocksOffTarget: "blocos fora do alvo",
        .incompleteStep: "bloco incompleto",
        .notExecuted: "bloco não executado",
        .easyTooHard: "FC alta no aquecimento ou no treino leve",
        .hardTooEasy: "esforço baixo nos blocos fortes",
        .heartRateTargetMissed: "FC fora do alvo",
        .lessEfficient: "menos eficiente que nos treinos anteriores",
        .moreEfficient: "mais eficiente que nos treinos anteriores",
        .noHeartRate: "sem FC no treino",
        .noZones: "sem zonas de FC",
        .noHistory: "sem treino anterior para comparar",
        .noPrescription: "sem prescrição",
        .slowerThanTarget: "mais lenta que a meta",
        .offStrategy: "km fora da estratégia",
        .noRaceTarget: "sem meta da prova",
        .noSplits: "sem tempo ou km completos",
        .noPreviousRace: "sem prova anterior para comparar",
        .lessEfficientThanRaces: "menos eficiente que nas provas anteriores",
        .moreEfficientThanRaces: "mais eficiente que nas provas anteriores",
    ]
}
