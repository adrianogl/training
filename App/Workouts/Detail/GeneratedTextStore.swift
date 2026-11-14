import CryptoKit
import Foundation

struct GeneratedTextStore {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func text(for key: [String]) -> String? {
        defaults.string(forKey: storageKey(key))
    }

    func save(_ text: String, for key: [String]) {
        defaults.set(text, forKey: storageKey(key))
    }

    private func storageKey(_ key: [String]) -> String {
        let digest = SHA256.hash(data: Data(key.joined(separator: "\n").utf8))
        return GeneratedTextConstants.keyPrefix + digest.map { String(format: "%02x", $0) }.joined()
    }
}
