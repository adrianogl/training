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
    let maxHeartRateText: String?
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

struct WorkoutReading: Equatable {
    let findings: [String]
    let evolution: String?
    let findingsOnDevice: Bool
    let evolutionOnDevice: Bool
}

struct WorkoutAnalysisInputs {
    let zones: HeartRateZones?
    let dailyLoad: [Day: Double]
    let readinessByDay: [String: Int]
}
