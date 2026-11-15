import Foundation

struct StravaBlockStep: Equatable, Sendable {
    let set: Int
    let size: String
}

struct StravaSimilar: Equatable, Sendable {
    let dateText: String
    let workPace: Double?
    let kilometers: Double
    let paceSeconds: Double?
    let heartRate: Double?
}

struct StravaSummaryInput: Equatable, Sendable {
    var kind: SessionKind
    var goalPace = false
    var steps: [StravaBlockStep] = []
    var workPace: Double?
    var kilometers: Double
    var paceSeconds: Double?
    var heartRate: Double?
    var score: Int?
    var fadeKm: Int?
    var similar: [StravaSimilar] = []
}
