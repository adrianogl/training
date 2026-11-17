import Foundation
import Insights

struct ClaudeStoredWorkout: Codable, Equatable {
    let workout: GeneratedStrengthWorkout
    let why: String?
    let summary: String?
}

enum ClaudeRequestPeriod: String, CaseIterable, Identifiable {
    case nextWeek, untilRace

    var id: String { rawValue }
}

struct ClaudeImportState: Identifiable {
    let id = UUID()
    let summary: String?
    let results: [ClaudeDayResult]
    let failure: String?
}
