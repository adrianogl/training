import Foundation
import Insights
import TrainingCore

struct TrainerZoneTrendKey: Equatable {
    let day: Day
    let runCount: Int
    let lastRunId: Int64?
    let target: TrainerTarget?
    let overrides: [TrainerPaceKind: Double]
}
