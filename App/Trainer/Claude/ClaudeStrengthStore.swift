import Foundation
import Insights
import TrainingCore

struct ClaudeStrengthStore {
    var defaults: UserDefaults = AccountScope.current.defaults

    func load(today: Day = Day.today()) -> [String: ClaudeStoredWorkout] {
        guard let data = defaults.data(forKey: ClaudeConstants.storeKey),
              let stored = try? JSONDecoder().decode([String: ClaudeStoredWorkout].self, from: data) else { return [:] }
        return stored.filter { key, _ in Day(iso: key).map { $0 >= today } ?? false }
    }

    func workout(on day: Day) -> ClaudeStoredWorkout? {
        load()[day.iso]
    }

    func apply(_ results: [ClaudeDayResult], summary: String?) {
        var stored = load()
        for result in results where result.isValid {
            guard let day = result.day, let workout = result.workout else { continue }
            stored[day.iso] = ClaudeStoredWorkout(workout: workout, why: result.why, summary: summary)
        }
        write(stored)
    }

    func remove(_ day: Day) {
        var stored = load()
        stored[day.iso] = nil
        write(stored)
    }

    func removeWeekdays(_ weekdays: Set<Int>, from today: Day = Day.today()) {
        guard !weekdays.isEmpty else { return }
        let stored = load(today: today).filter { key, _ in
            guard let day = Day(iso: key) else { return false }
            return !weekdays.contains(day.weekStart.days(until: day) + 1)
        }
        write(stored)
    }

    private func write(_ stored: [String: ClaudeStoredWorkout]) {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: ClaudeConstants.storeKey)
    }
}
