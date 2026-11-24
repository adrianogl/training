import Foundation

enum TrainerWeekItems {
    static func items(rows: [TrainerDayRow], done: [WorkoutRowData]) -> [TrainerWeekItem] {
        let doneDays = Set(done.map(\.dayIso))
        let plannedDays = Set(rows.map(\.workout.day.iso))
        let days = doneDays.union(plannedDays).sorted()
        return days.flatMap { day -> [TrainerWeekItem] in
            if doneDays.contains(day) {
                return done.filter { $0.dayIso == day }.map(TrainerWeekItem.done)
            }
            return rows.filter { $0.workout.day.iso == day }.map(TrainerWeekItem.planned)
        }
    }
}
