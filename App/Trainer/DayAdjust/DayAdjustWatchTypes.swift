import Foundation
import Insights

struct IncludedHeat: Codable, Equatable {
    let share: Double
    let title: String
}

struct DayAdjustWatch: Equatable {
    let entries: DayAdjustEntries
    let workout: TrainerWorkout
    let result: TrainerDayAdjustResult
    let sentAt: Date?
}
