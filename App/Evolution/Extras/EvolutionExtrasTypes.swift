import Foundation
import TrainingCore

struct ZoneWeek: Equatable, Sendable, Codable {
    let start: Day
    let seconds: [Double]
}

struct PersonalRecord: Equatable, Sendable, Codable {
    let label: String
    let seconds: Double
    let date: Date
    let source: String
    var meters: Double? = nil
}
