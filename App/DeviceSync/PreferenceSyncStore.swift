import CryptoKit
import Foundation
import RemoteSync

struct PreferenceSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    nonisolated(unsafe) let defaults: UserDefaults
    let now: @Sendable () -> Date

    private static let lock = NSLock()
    private typealias C = DeviceSyncConstants

    init(defaults: UserDefaults = AccountScope.current.defaults, now: @escaping @Sendable () -> Date = { .now }) {
        self.defaults = defaults
        self.now = now
    }

    func pendingBlobs() -> [RemoteBlob] {
        Self.lock.withLock {
            var state = loadState()
            let stamp = Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds(now())) / 1_000)
            var blobs: [RemoteBlob] = []
            for id in trackedIds() {
                guard let data = encoded(defaults.object(forKey: id)) else { continue }
                let digest = Self.digest(data)
                if state[id]?.digest != digest {
                    state[id] = PreferenceSyncEntry(digest: digest, updatedAt: stamp, pending: true)
                }
                if let entry = state[id], entry.pending {
                    blobs.append(RemoteBlob(id: id, data: data, updatedAt: entry.updatedAt))
                }
            }
            saveState(state)
            return blobs
        }
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        Self.lock.withLock {
            var state = loadState()
            for blob in blobs where state[blob.id]?.updatedAt == blob.updatedAt {
                state[blob.id]?.pending = false
            }
            saveState(state)
        }
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        Self.lock.withLock {
            var state = loadState()
            guard isTracked(blob.id), let value = decoded(blob.data) else { return false }
            if C.unionKeys.contains(blob.id), let remote = value as? [Any] {
                return applyUnion(remote, blob: blob, state: &state)
            }
            if let local = state[blob.id], RemoteTimestamp.milliseconds(local.updatedAt) >= RemoteTimestamp.milliseconds(blob.updatedAt) {
                return false
            }
            defaults.set(value, forKey: blob.id)
            let digest = encoded(defaults.object(forKey: blob.id)).map(Self.digest) ?? ""
            state[blob.id] = PreferenceSyncEntry(digest: digest, updatedAt: blob.updatedAt, pending: false)
            saveState(state)
            return true
        }
    }

    private func applyUnion(_ remote: [Any], blob: RemoteBlob, state: inout [String: PreferenceSyncEntry]) -> Bool {
        let local = defaults.array(forKey: blob.id) ?? []
        let merged = NSMutableOrderedSet(array: local)
        merged.addObjects(from: remote)
        let values = merged.array
        guard !(values as NSArray).isEqual(to: local) else { return false }
        defaults.set(values, forKey: blob.id)
        let digest = encoded(defaults.object(forKey: blob.id)).map(Self.digest) ?? ""
        let matchesRemote = (values as NSArray).isEqual(to: remote)
        let stamp = Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds(now())) / 1_000)
        state[blob.id] = PreferenceSyncEntry(digest: digest, updatedAt: matchesRemote ? blob.updatedAt : max(stamp, blob.updatedAt), pending: !matchesRemote)
        saveState(state)
        return true
    }

    func handles(_ id: String) -> Bool {
        isTracked(id)
    }

    private func trackedIds() -> [String] {
        let prefixed = defaults.dictionaryRepresentation().keys.filter { key in C.trackedPrefixes.contains { key.hasPrefix($0) } }
        return C.trackedKeys + prefixed.sorted()
    }

    private func isTracked(_ id: String) -> Bool {
        C.trackedKeys.contains(id) || C.trackedPrefixes.contains { id.hasPrefix($0) }
    }

    private func encoded(_ value: Any?) -> Data? {
        guard let value else { return nil }
        return try? PropertyListSerialization.data(fromPropertyList: [C.plistValueKey: value], format: .binary, options: 0)
    }

    private func decoded(_ data: Data) -> Any? {
        let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return (plist as? [String: Any])?[C.plistValueKey]
    }

    private func loadState() -> [String: PreferenceSyncEntry] {
        defaults.data(forKey: C.preferenceStateKey).flatMap { try? JSONDecoder().decode([String: PreferenceSyncEntry].self, from: $0) } ?? [:]
    }

    private func saveState(_ state: [String: PreferenceSyncEntry]) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: C.preferenceStateKey)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
