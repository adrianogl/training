import Foundation
import Insights

struct TrainerStore {
    let url: URL
    let defaults: UserDefaults

    init(url: URL = TrainerStore.defaultURL(), defaults: UserDefaults = .standard) {
        self.url = url
        self.defaults = defaults
    }

    static func defaultURL() -> URL {
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return support.appending(path: TrainerConstants.storeFileName)
    }

    var seenVersion: Int {
        defaults.integer(forKey: TrainerConstants.seenVersionDefaultsKey)
    }

    var strengthMigrated: Bool {
        defaults.bool(forKey: TrainerConstants.strengthMigratedDefaultsKey)
    }

    func markStrengthMigrated() {
        defaults.set(true, forKey: TrainerConstants.strengthMigratedDefaultsKey)
    }

    func markSeen(_ version: Int) {
        defaults.set(version, forKey: TrainerConstants.seenVersionDefaultsKey)
    }

    func load() -> TrainerPlan? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder.decode(TrainerPlan.self, from: data)
    }

    func save(_ plan: TrainerPlan) throws {
        try Self.encoder.encode(plan).write(to: url, options: .atomic)
    }

    func delete() throws {
        defaults.removeObject(forKey: TrainerConstants.seenVersionDefaultsKey)
        defaults.removeObject(forKey: TrainerConstants.strengthMigratedDefaultsKey)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
