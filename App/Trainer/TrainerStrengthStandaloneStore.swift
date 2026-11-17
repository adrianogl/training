import Foundation
import Insights

struct TrainerStrengthStandaloneStore {
    var defaults: UserDefaults = AccountScope.current.defaults

    func load() -> [TrainerStrengthSession] {
        guard let data = defaults.data(forKey: TrainerStrengthConstants.standaloneKey),
              let sessions = try? JSONDecoder().decode([TrainerStrengthSession].self, from: data) else { return [] }
        return sessions
    }

    func save(_ sessions: [TrainerStrengthSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: TrainerStrengthConstants.standaloneKey)
    }
}
