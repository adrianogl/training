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
}
