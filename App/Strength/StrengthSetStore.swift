import Foundation
import GarminAPI

struct StrengthSetStore: Sendable {
    let url: URL

    init(url: URL = AccountScope.current.strengthSetsURL) {
        self.url = url
    }

    func load() -> [Int64: [StrengthSet]] {
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([String: [StrengthSet]].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in Int64(key).map { ($0, value) } })
    }

    func save(_ sets: [Int64: [StrengthSet]]) {
        let stored = Dictionary(uniqueKeysWithValues: sets.map { (String($0.key), $0.value) })
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
