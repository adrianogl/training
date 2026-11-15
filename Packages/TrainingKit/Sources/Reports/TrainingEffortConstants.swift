import Metrics
import WorkoutAnalysis

enum TrainingEffortConstants {
    static let threshold = TrainingEffortRule(runKind: .tempo, effortKind: .threshold, minimumMeters: 5_000, distance: 10_000, paceOffset: -7)
    static let interval = TrainingEffortRule(runKind: .intervals, effortKind: .interval, minimumMeters: 3_000, distance: 5_000, paceOffset: 4)
    static let sessions = 4
    static let windowDays = 90
    static let metersPerKilometer = 1_000.0
}
