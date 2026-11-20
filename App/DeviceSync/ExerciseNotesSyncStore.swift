import Foundation
import RemoteSync

struct ExerciseNotesSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    let store: ExerciseNotesStore
    nonisolated(unsafe) let defaults: UserDefaults

    private typealias C = ExerciseNotesConstants

    func handles(_ id: String) -> Bool {
        id == C.blobId
    }

    func pendingBlobs() -> [RemoteBlob] {
        let entries = store.all()
        guard let latest = entries.map(\.updatedAt).max() else { return [] }
        let stamp = Date(timeIntervalSince1970: Double(RemoteTimestamp.milliseconds(latest)) / 1_000)
        if let synced = defaults.object(forKey: C.syncedStampKey) as? Double,
           RemoteTimestamp.milliseconds(Date(timeIntervalSince1970: synced)) >= RemoteTimestamp.milliseconds(stamp) { return [] }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(entries) else { return [] }
        return [RemoteBlob(id: C.blobId, data: data, updatedAt: stamp)]
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        guard let blob = blobs.first(where: { $0.id == C.blobId }) else { return }
        let current = (defaults.object(forKey: C.syncedStampKey) as? Double) ?? 0
        defaults.set(max(current, blob.updatedAt.timeIntervalSince1970), forKey: C.syncedStampKey)
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        guard blob.id == C.blobId, let remote = try? JSONDecoder().decode([ExerciseNote].self, from: blob.data) else { return false }
        return store.merge(remote)
    }
}
