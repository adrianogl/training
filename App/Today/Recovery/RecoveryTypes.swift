import Foundation

struct RecoveryRun: Equatable, Sendable {
    let title: String
    let end: Date
    let aerobicEffect: Double?
    let anaerobicEffect: Double?
    let typicalHour: Int
}

struct RecoveryNext: Equatable {
    let title: String
    let start: Date
    let gapHours: Int
    let enough: Bool
}

struct RecoveryEstimate: Equatable {
    let title: String
    let hours: Int
    let readyAt: Date
    let progress: Double
    let next: RecoveryNext?
}
