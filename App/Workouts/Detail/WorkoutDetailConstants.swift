import CoreGraphics
import Foundation

enum WorkoutDetailConstants {
    static let defaultZonesSport = "DEFAULT"
    static let kmSplitDistance = 1_000.0
    static let minimumPartialSplit = 100.0
    static let kmLabel = "Km"
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
    static let valueColumnWidth: CGFloat = 52
    static let dotColumnWidth: CGFloat = 14
    static let barHeight: CGFloat = 8
    static let bandHeight: CGFloat = 14
    static let comparisonValueWidth: CGFloat = 58
    static let paceDeltaThreshold = 1.0
    static let heartRateDeltaThreshold = 1.0
}
