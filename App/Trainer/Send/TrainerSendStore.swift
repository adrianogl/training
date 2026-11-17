import Foundation

struct TrainerSendStore {
    var defaults: UserDefaults = AccountScope.current.defaults

    func records() -> [String: TrainerSentRecord] {
        guard let data = defaults.data(forKey: TrainerSendConstants.recordsKey),
              let records = try? JSONDecoder().decode([String: TrainerSentRecord].self, from: data) else { return [:] }
        return records
    }

    func record(_ record: TrainerSentRecord, key: String) {
        var all = records()
        all[key] = record
        write(all)
    }

    func remove(key: String) {
        var all = records()
        all[key] = nil
        write(all)
    }

    func settings() -> TrainerSendSettings {
        guard let data = defaults.data(forKey: TrainerSendConstants.settingsKey),
              let settings = try? JSONDecoder().decode(TrainerSendSettings.self, from: data) else { return TrainerSendSettings() }
        return settings
    }

    func save(_ settings: TrainerSendSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: TrainerSendConstants.settingsKey)
    }

    private func write(_ records: [String: TrainerSentRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: TrainerSendConstants.recordsKey)
    }
}
