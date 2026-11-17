import CryptoKit
import Foundation
import RemoteSync

struct WatchTokenSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    let tokenStore: any APIKeyStore
    nonisolated(unsafe) let defaults: UserDefaults
    let now: @Sendable () -> Date

    private static let lock = NSLock()
    private typealias C = DeviceSyncConstants

    init(tokenStore: any APIKeyStore, defaults: UserDefaults, now: @escaping @Sendable () -> Date = { .now }) {
        self.tokenStore = tokenStore
        self.defaults = defaults
        self.now = now
    }

    func handles(_ id: String) -> Bool {
        id == C.watchTokenId
    }

    func pendingBlobs() -> [RemoteBlob] {
        Self.lock.withLock {
            guard let token = ((try? tokenStore.read()) ?? nil), !token.isEmpty else { return [] }
            let digest = Self.digest(token)
            var entry = loadEntry()
            if entry?.digest != digest {
                entry = PreferenceSyncEntry(digest: digest, updatedAt: Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds(now())) / 1_000), pending: true)
                saveEntry(entry)
            }
            guard let entry, entry.pending else { return [] }
            return [RemoteBlob(id: C.watchTokenId, data: Data(token.utf8), updatedAt: entry.updatedAt)]
        }
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        Self.lock.withLock {
            guard var entry = loadEntry(), blobs.contains(where: { $0.id == C.watchTokenId && $0.updatedAt == entry.updatedAt }) else { return }
            entry.pending = false
            saveEntry(entry)
        }
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        Self.lock.withLock {
            guard blob.id == C.watchTokenId, let token = String(data: blob.data, encoding: .utf8), !token.isEmpty else { return false }
            if let local = loadEntry(), RemoteTimestamp.milliseconds(local.updatedAt) >= RemoteTimestamp.milliseconds(blob.updatedAt) { return false }
            guard (try? tokenStore.save(token)) != nil else { return false }
            saveEntry(PreferenceSyncEntry(digest: Self.digest(token), updatedAt: blob.updatedAt, pending: false))
            return true
        }
    }

    private func loadEntry() -> PreferenceSyncEntry? {
        defaults.data(forKey: C.watchTokenStateKey).flatMap { try? JSONDecoder().decode(PreferenceSyncEntry.self, from: $0) }
    }

    private func saveEntry(_ entry: PreferenceSyncEntry?) {
        guard let entry, let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: C.watchTokenStateKey)
    }

    private static func digest(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
