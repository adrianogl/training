import Foundation
import TrainingCore

enum Command: String {
    case sync, report
}

struct Invocation {
    var command: Command
    var store: URL
}

enum CLIError: Error {
    case usage(String)
    case missingKey(path: String)
    case emptyKey(path: String)
}

struct DatedValue {
    var day: Day
    var value: Double
}

struct Prediction {
    var label: String
    var seconds: Double?
}

struct TrainingReport {
    var days: Int
    var activities: Int
    var today: Day
    var readinessScore: Int?
    var readinessPartial: Bool
    var vo2max: DatedValue?
    var fitness: Double?
    var fatigue: Double?
    var form: Double?
    var acuteChronic: Double?
    var predictions: [Prediction]
    var durability: DatedValue?
    var hillStrength: DatedValue?
}
