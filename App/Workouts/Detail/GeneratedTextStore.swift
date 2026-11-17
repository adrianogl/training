import CryptoKit
import Foundation
import RemoteSync

struct GeneratedTextStore: Sendable {
    nonisolated(unsafe) let defaults: UserDefaults
    let now: @Sendable () -> Date

    private static let lock = NSLock()
    private typealias C = GeneratedTextConstants

    init(defaults: UserDefaults = AccountScope.current.defaults, now: @escaping @Sendable () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
    }

    func text(for key: [String]) -> String? {
        entry(id: Self.id(for: key))?.text
    }

    func save(_ text: String, for key: [String]) {
        let id = Self.id(for: key)
        let stamp = Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds(now())) / 1_000)
        Self.lock.withLock {
            write(GeneratedTextEntry(text: text, updatedAt: stamp), id: id)
            defaults.set(Array(pendingIds.union([id])).sorted(), forKey: C.pendingKey)
        }
    }

    static func id(for key: [String]) -> String {
        let digest = SHA256.hash(data: Data(([C.version] + key).joined(separator: "\n").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private var pendingIds: Set<String> {
        Set(defaults.stringArray(forKey: C.pendingKey) ?? [])
    }

    private func entry(id: String) -> GeneratedTextEntry? {
        defaults.data(forKey: C.entryPrefix + id).flatMap { try? JSONDecoder().decode(GeneratedTextEntry.self, from: $0) }
    }

    private func write(_ entry: GeneratedTextEntry, id: String) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: C.entryPrefix + id)
    }
}

extension GeneratedTextStore: RemoteNarrativeStore {
    func pendingNarratives() -> [RemoteNarrative] {
        Self.lock.withLock {
            pendingIds.sorted().compactMap { id in
                entry(id: id).map { RemoteNarrative(id: id, text: $0.text, updatedAt: $0.updatedAt) }
            }
        }
    }

    func narrativeUpdatedAt(id: String) -> Date? {
        entry(id: id)?.updatedAt
    }

    func markNarrativesPushed(_ narratives: [RemoteNarrative]) {
        Self.lock.withLock {
            let pushed = narratives.filter { entry(id: $0.id) == GeneratedTextEntry(text: $0.text, updatedAt: $0.updatedAt) }.map(\.id)
            defaults.set(Array(pendingIds.subtracting(pushed)).sorted(), forKey: C.pendingKey)
        }
    }

    func apply(_ narrative: RemoteNarrative) -> Bool {
        Self.lock.withLock {
            write(GeneratedTextEntry(text: narrative.text, updatedAt: narrative.updatedAt), id: narrative.id)
            defaults.set(Array(pendingIds.subtracting([narrative.id])).sorted(), forKey: C.pendingKey)
        }
        return true
    }
}
