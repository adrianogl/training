import Foundation
import Insights

struct TrainerStrengthPrefsStore {
    var defaults: UserDefaults = AccountScope.current.defaults

    func load() -> TrainerStrengthPrefs {
        guard let data = defaults.data(forKey: TrainerStrengthConstants.prefsKey),
              let prefs = try? JSONDecoder().decode(TrainerStrengthPrefs.self, from: data) else { return TrainerStrengthPrefs() }
        return prefs
    }

    func save(_ prefs: TrainerStrengthPrefs) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        defaults.set(data, forKey: TrainerStrengthConstants.prefsKey)
    }

    func toggleHomeEquipment(_ equipment: StrengthEquipment) {
        guard equipment != .bodyweight else { return }
        var prefs = load()
        var chosen = prefs.effectiveHomeEquipment
        if chosen.contains(equipment) { chosen.remove(equipment) } else { chosen.insert(equipment) }
        prefs.homeEquipment = chosen
        save(prefs)
    }

    func setPain(_ regions: Set<BodyRegion>, now: Date = .now) {
        var prefs = load()
        prefs.pain = regions
        prefs.painMarkedAt = regions.isEmpty ? nil : now
        save(prefs)
    }

    func swap(_ from: String, to: String, on day: String) {
        var prefs = load()
        prefs.swaps[day, default: [:]][from] = to
        save(prefs)
    }

    func setKeptOriginal(_ kept: Bool, on day: String) {
        var prefs = load()
        if kept { prefs.keptOriginal.insert(day) } else { prefs.keptOriginal.remove(day) }
        save(prefs)
    }
}
