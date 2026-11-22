import Foundation
import Insights
import TrainingCore

struct TrainerCycleSummary: Codable, Equatable, Identifiable {
    var title: String
    var first: Day
    var last: Day
    var verdict: TrainerCycleVerdict
    var beforePeakMeters: Double
    var afterPeakMeters: Double
    var resultSeconds: Double?

    var id: String { last.iso }
}

struct TrainerCycleEditor: Identifiable {
    let isEditing: Bool
    let start: Int?
    let peak: Int?
    var days: TrainerDayPreference? = nil

    var id: String { "\(isEditing)-\(start ?? 0)-\(peak ?? 0)-\(days?.runs ?? 0)" }

    var volumes: (start: Int, peak: Int)? {
        guard let start, let peak else { return nil }
        return (start, peak)
    }
}
