import Foundation
import MFIT
import RemoteSync

struct StrengthSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    let store: StrengthProgramStore
    nonisolated(unsafe) let defaults: UserDefaults

    private static let lock = NSLock()
    private typealias C = DeviceSyncConstants

    func handles(_ id: String) -> Bool {
        id == C.strengthId
    }

    func pendingBlobs() -> [RemoteBlob] {
        Self.lock.withLock {
            guard let stamp = modified(), let data = try? Data(contentsOf: store.url) else { return [] }
            if let synced = syncedStamp(), RemoteTimestamp.milliseconds(synced) >= RemoteTimestamp.milliseconds(stamp) { return [] }
            return [RemoteBlob(id: C.strengthId, data: data, updatedAt: stamp)]
        }
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        Self.lock.withLock {
            guard let blob = blobs.first(where: { $0.id == C.strengthId }) else { return }
            defaults.set(max(syncedStamp() ?? .distantPast, blob.updatedAt).timeIntervalSince1970, forKey: C.strengthStateKey)
        }
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        Self.lock.withLock {
            guard blob.id == C.strengthId, let remote = try? JSONDecoder().decode(StrengthProgramCache.self, from: blob.data) else { return false }
            let local = store.load()
            let localStamp = modified() ?? .distantPast
            let merged = Self.merge(local: local, remote: remote, remoteIsNewer: blob.updatedAt > localStamp)
            guard let mergedData = try? JSONEncoder().encode(merged), let localData = try? JSONEncoder().encode(local), mergedData != localData else {
                return false
            }
            store.save(merged)
            if let remoteData = try? JSONEncoder().encode(remote), remoteData == mergedData, let stamp = modified() {
                defaults.set(stamp.timeIntervalSince1970, forKey: C.strengthStateKey)
            }
            return true
        }
    }

    static func merge(local: StrengthProgramCache, remote: StrengthProgramCache, remoteIsNewer: Bool) -> StrengthProgramCache {
        let (newer, older) = remoteIsNewer ? (remote, local) : (local, remote)
        var known = Dictionary(older.known.map { ($0.id, $0) }) { first, _ in first }
        for workout in newer.known { known[workout.id] = workout }
        var loads: [String: MFITLoadRecord] = [:]
        for record in older.loads + newer.loads { loads[identity(record)] = record }
        return StrengthProgramCache(
            program: newer.program ?? older.program,
            known: known.values.sorted { $0.id < $1.id },
            loads: loads.values.sorted { ($0.day, $0.key, $0.workoutId) < ($1.day, $1.key, $1.workoutId) },
            watchProcessed: Array(Set(older.watchProcessed + newer.watchProcessed)).sorted()
        )
    }

    private static func identity(_ record: MFITLoadRecord) -> String {
        "\(record.key)|\(record.day)|\(record.workoutId)|\(record.fromWatch == true)"
    }

    private func modified() -> Date? {
        (try? store.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            .map { Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds($0)) / 1_000) }
    }

    private func syncedStamp() -> Date? {
        (defaults.object(forKey: C.strengthStateKey) as? Double).map(Date.init(timeIntervalSince1970:))
    }
}
