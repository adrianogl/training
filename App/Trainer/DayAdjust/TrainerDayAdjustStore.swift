import Foundation
import Insights
import TrainingCore

struct TrainerDayAdjustStore {
    var defaults: UserDefaults = AccountScope.current.defaults

    func load(day: Day) -> DayAdjustEntries? {
        guard let data = defaults.data(forKey: DayAdjustWatchConstants.storeKey),
              let entries = try? JSONDecoder().decode(DayAdjustEntries.self, from: data), entries.day == day else { return nil }
        return entries
    }

    func save(_ entries: DayAdjustEntries) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: DayAdjustWatchConstants.storeKey)
    }

    @discardableResult
    func clear(day: Day) -> Bool {
        guard load(day: day) != nil else { return false }
        defaults.removeObject(forKey: DayAdjustWatchConstants.storeKey)
        return true
    }
}
