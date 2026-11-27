import Foundation

enum TrainerWeekItems {
    static func items(rows: [TrainerDayRow], done: [WorkoutRowData]) -> [TrainerWeekItem] {
        let doneDays = Set(done.map(\.dayIso))
        let plannedDays = Set(rows.map(\.workout.day.iso))
        let days = doneDays.union(plannedDays).sorted()
        return days.flatMap { day -> [TrainerWeekItem] in
            let planned = rows.filter { $0.workout.day.iso == day }
            let doneOnDay = done.filter { $0.dayIso == day }
            guard !doneOnDay.isEmpty else { return planned.map(TrainerWeekItem.planned) }
            let runs = doneOnDay.filter { !$0.isStrength }
            if !runs.isEmpty, let run = planned.first(where: { $0.workout.kind != .off }) {
                return [.plannedDone(run, runs)] + doneOnDay.filter(\.isStrength).map(TrainerWeekItem.done)
            }
            if runs.isEmpty, !planned.isEmpty {
                return planned.map(TrainerWeekItem.planned) + doneOnDay.map(TrainerWeekItem.done)
            }
            return doneOnDay.map(TrainerWeekItem.done)
        }
    }
}
