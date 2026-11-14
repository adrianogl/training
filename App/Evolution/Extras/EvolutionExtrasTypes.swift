import Foundation
import TrainingCore

struct ZoneWeek: Equatable, Sendable {
    let start: Day
    let seconds: [Double]
}

struct PersonalRecord: Equatable, Sendable {
    let label: String
    let seconds: Double
    let date: Date
    let source: String
}
