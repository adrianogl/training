import Foundation
import TrainingCore
import WorkoutAnalysis

struct WorkoutSummary: Equatable {
    let title: String
    let dateText: String
    let subtitle: String
    let distanceText: String?
    let durationText: String?
    let paceText: String?
    let averageHeartRateText: String?
    let elevationText: String?
    let loadText: String?
    let hasPrescription: Bool
}

struct ComparisonRow: Identifiable, Equatable, Sendable {
    let activityId: Int64
    let dateText: String
    let isCurrent: Bool
    let paceText: String?
    let heartRateText: String?
    let inTargetText: String?
    let secondsPerKilometer: Double?
    let heartRate: Double?

    var id: Int64 { activityId }
}

enum BlockMetric: Equatable {
    case speed, heartRate
}

struct BlockBar: Equatable {
    let metric: BlockMetric
    let band: ClosedRange<Double>?
    let actual: ClosedRange<Double>?
    let valueText: String?
}

struct ScaledBars: Equatable {
    let blocks: [BlockBar]
    let kilometers: [Int: [BlockBar]]
}

struct ZoneBand: Equatable {
    let zone: Int
    let low: Double
    let high: Double
}

struct BlockSpan: Equatable {
    let start: Double
    let end: Double
}

struct ZoneShare: Equatable {
    let zone: Int
    let share: Double
    let seconds: Double
}

struct TrainingEffectData: Equatable {
    let label: String?
    let aerobic: Double?
    let anaerobic: Double?
    let highZoneSeconds: Double?
    let load: Double?
}

struct AnalysisItem: Identifiable, Equatable {
    let id: Int
    let text: String
    let evidence: String?
    let why: String
    let blockOrdinal: Int?
}

struct AnalysisColumns: Equatable {
    let negative: [AnalysisItem]
    let positive: [AnalysisItem]
    let expected: [AnalysisItem]
}

struct WorkoutReading: Equatable {
    let findings: [String]
    let evolution: String?
    let findingsOnDevice: Bool
    let evolutionOnDevice: Bool
}

struct ScoreRowData: Identifiable, Equatable {
    let part: ScorePart
    let name: String
    let points: Double
    let maximum: Double
    let pointsText: String?
    let reasonText: String?

    var id: ScorePart { part }
    var isIncluded: Bool { maximum > 0 }
}

struct WorkoutAnalysisInputs {
    let watchZones: HeartRateZones?
    let thresholdByDay: [Day: Int]
    let dailyLoad: [Day: Double]
    let readinessByDay: [String: Int]
}

struct ZoneBar: Equatable, Sendable {
    let floors: [Int]
    let seconds: [Double]
}

struct ZoneRulerData: Equatable, Sendable {
    let watch: ZoneBar
    let threshold: ZoneBar?
    let divergence: Int?
    let thresholdHeartRate: Int?
}

struct ZoneSegment: Equatable {
    let zone: Int
    let start: Double
    let end: Double
}

struct ZoneMark: Equatable, Identifiable {
    let id: Int
    let bpm: Int
    let position: Double
}
