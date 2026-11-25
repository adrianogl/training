import Foundation
import TrainingCore

struct IncludedHeatStore {
    var defaults: UserDefaults = AccountScope.current.defaults

    func all() -> [Day: IncludedHeat] {
        guard let data = defaults.data(forKey: DayAdjustWatchConstants.includedHeatKey),
              let stored = try? JSONDecoder().decode([String: IncludedHeat].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in Day(iso: key).map { ($0, value) } })
    }

    func absorb(_ records: [String: TrainerSentRecord]) {
        var stored = Dictionary(uniqueKeysWithValues: all().map { ($0.key.iso, $0.value) })
        var changed = false
        for (key, record) in records where key.hasPrefix(TrainerSendConstants.runKeyPrefix) && record.kind == .run {
            guard let share = record.heatShare, let title = record.title else { continue }
            let heat = IncludedHeat(share: share, title: title)
            guard stored[record.day] != heat else { continue }
            stored[record.day] = heat
            changed = true
        }
        guard changed, let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: DayAdjustWatchConstants.includedHeatKey)
    }
}
