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
