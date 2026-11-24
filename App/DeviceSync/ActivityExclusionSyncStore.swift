import Foundation
import RemoteSync

struct ActivityExclusionSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    let store: ActivityExclusionStore
    nonisolated(unsafe) let defaults: UserDefaults

    private typealias C = ActivityExclusionConstants

    func handles(_ id: String) -> Bool {
        id == C.blobId
    }

    func pendingBlobs() -> [RemoteBlob] {
        guard let stamp = modified(), let data = try? Data(contentsOf: store.url) else { return [] }
        if let synced = syncedStamp(), RemoteTimestamp.milliseconds(synced) >= RemoteTimestamp.milliseconds(stamp) { return [] }
        return [RemoteBlob(id: C.blobId, data: data, updatedAt: stamp)]
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        guard let blob = blobs.first(where: { $0.id == C.blobId }) else { return }
        defaults.set(max(syncedStamp() ?? .distantPast, blob.updatedAt).timeIntervalSince1970, forKey: C.syncedStampKey)
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        guard blob.id == C.blobId, let remote = try? JSONDecoder().decode(ActivityExclusions.self, from: blob.data) else { return false }
        let local = store.load()
        let merged = local.merged(with: remote)
        guard merged != local else {
            if merged == remote { defaults.set(blob.updatedAt.timeIntervalSince1970, forKey: C.syncedStampKey) }
            return false
        }
        store.save(merged)
        if merged == remote, let stamp = modified() { defaults.set(stamp.timeIntervalSince1970, forKey: C.syncedStampKey) }
        return true
    }

    private func modified() -> Date? {
        (try? store.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            .map { Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds($0)) / 1_000) }
    }

    private func syncedStamp() -> Date? {
        (defaults.object(forKey: C.syncedStampKey) as? Double).map(Date.init(timeIntervalSince1970:))
    }
}
