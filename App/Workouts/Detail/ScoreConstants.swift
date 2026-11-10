import CoreGraphics
import WorkoutAnalysis

enum ScoreConstants {
    static let badgeCaption = "nota"
    static let breakdownTitle = "Nota do treino"
    static let excludedSuffix = "fora da nota"
    static let strongThreshold = 80
    static let moderateThreshold = 60
    static let detailBadgeSize: CGFloat = 56
    static let rowBadgeSize: CGFloat = 28
    static let cardBadgeSize: CGFloat = 34
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
    ]
}
