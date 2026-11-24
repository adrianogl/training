import Foundation

enum WorkoutListMode: String, CaseIterable, Identifiable {
    case list, week, calendar

    var id: String { rawValue }
}

struct WorkoutCalendarDay: Equatable {
    var ran = false
    var plannedRun = false
    var strength = false
    var mfit = false
    var kilometers: Double = 0
}

struct WorkoutCalendarSummary: Equatable {
    let runs: Int
    let kilometers: Double
    let strength: Int
}
