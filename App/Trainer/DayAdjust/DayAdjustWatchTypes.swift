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

struct DayAdjustHourOption: Equatable {
    let hour: Int
    let entries: DayAdjustEntries
    let result: TrainerDayAdjustResult
    let seconds: Int
    let paceLow: Double?
}
