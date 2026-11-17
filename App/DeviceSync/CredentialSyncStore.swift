import CryptoKit
import Foundation
import RemoteSync

struct CredentialSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    let id: String
    let tokenStore: any APIKeyStore
    nonisolated(unsafe) let defaults: UserDefaults
    let now: @Sendable () -> Date

    private static let lock = NSLock()

    init(id: String, tokenStore: any APIKeyStore, defaults: UserDefaults, now: @escaping @Sendable () -> Date = { .now }) {
        self.id = id
        self.tokenStore = tokenStore
        self.defaults = defaults
        self.now = now
    }

    func handles(_ id: String) -> Bool {
        id == self.id
    }

    func pendingBlobs() -> [RemoteBlob] {
        Self.lock.withLock {
            let token = ((try? tokenStore.read()) ?? nil) ?? ""
            let digest = Self.digest(token)
            var entry = loadEntry()
            if token.isEmpty, entry?.pending != true { return [] }
            if !token.isEmpty, entry?.digest != digest {
                entry = PreferenceSyncEntry(digest: digest, updatedAt: Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds(now())) / 1_000), pending: true)
                saveEntry(entry)
            }
            guard let entry, entry.pending else { return [] }
            return [RemoteBlob(id: id, data: Data(token.utf8), updatedAt: entry.updatedAt)]
        }
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        Self.lock.withLock {
            guard var entry = loadEntry(), blobs.contains(where: { $0.id == id && $0.updatedAt == entry.updatedAt }) else { return }
            entry.pending = false
            saveEntry(entry)
        }
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        Self.lock.withLock {
            guard blob.id == id, let token = String(data: blob.data, encoding: .utf8) else { return false }
            if let local = loadEntry(), RemoteTimestamp.milliseconds(local.updatedAt) >= RemoteTimestamp.milliseconds(blob.updatedAt) { return false }
            if token.isEmpty {
                try? tokenStore.delete()
            } else {
                guard (try? tokenStore.save(token)) != nil else { return false }
            }
            saveEntry(PreferenceSyncEntry(digest: Self.digest(token), updatedAt: blob.updatedAt, pending: false))
            return true
        }
    }

    static func recordSignOut(id: String, defaults: UserDefaults, now: Date = .now) {
        lock.withLock {
            let entry = PreferenceSyncEntry(digest: digest(""), updatedAt: Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds(now)) / 1_000), pending: true)
            guard let data = try? JSONEncoder().encode(entry) else { return }
            defaults.set(data, forKey: DeviceSyncConstants.credentialStatePrefix + id)
        }
    }

    private var stateKey: String {
        DeviceSyncConstants.credentialStatePrefix + id
    }

    private func loadEntry() -> PreferenceSyncEntry? {
        defaults.data(forKey: stateKey).flatMap { try? JSONDecoder().decode(PreferenceSyncEntry.self, from: $0) }
    }

    private func saveEntry(_ entry: PreferenceSyncEntry?) {
        guard let entry, let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: stateKey)
    }

    private static func digest(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
