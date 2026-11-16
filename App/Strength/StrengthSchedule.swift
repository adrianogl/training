import Foundation
import GarminAPI
import MFIT
import TrainingCore

struct StrengthSchedule {
    private typealias C = StrengthConstants

    let defaults: UserDefaults

    init(defaults: UserDefaults = AccountScope.current.defaults) {
        self.defaults = defaults
    }

    private var overrides: [String: Int] {
        defaults.dictionary(forKey: C.weekdaysDefaultsKey) as? [String: Int] ?? [:]
    }

    func weekday(for workout: MFITWorkout) -> Int? {
        if let chosen = overrides[String(workout.id)] { return chosen == C.noWeekday ? nil : chosen }
        return C.defaultWeekdays.indices.contains(workout.order) ? C.defaultWeekdays[workout.order] : nil
    }

    func setWeekday(_ weekday: Int?, for workout: MFITWorkout) {
        var updated = overrides
        updated[String(workout.id)] = weekday ?? C.noWeekday
        defaults.set(updated, forKey: C.weekdaysDefaultsKey)
    }

    func workouts(_ program: MFITProgram?, from first: Day, through last: Day) -> [StrengthWorkout] {
        guard let program else { return [] }
        var result: [StrengthWorkout] = []
        var day = first.weekStart
        while day <= last {
            for workout in program.workouts {
                guard let weekday = weekday(for: workout) else { continue }
                let date = day.adding(days: weekday)
                guard first <= date, date <= last, program.contains(date.iso) else { continue }
                result.append(StrengthWorkout(id: workout.id, day: date.iso, title: workout.title, blocks: workout.blocks))
            }
            day = day.adding(days: 7)
        }
        return result.sorted { $0.day < $1.day }
    }
}
