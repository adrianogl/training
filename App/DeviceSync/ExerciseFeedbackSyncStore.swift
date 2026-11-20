import Foundation
import RemoteSync

struct ExerciseFeedbackSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    let store: ExerciseFeedbackStore
    nonisolated(unsafe) let defaults: UserDefaults

    private typealias C = ExerciseFeedbackConstants

    private var stamps: SyncDocumentStamp {
        SyncDocumentStamp(defaults: defaults, syncedKey: C.syncedStampKey, documentKey: C.documentStampKey)
    }

    func handles(_ id: String) -> Bool {
        id == C.blobId
    }

    func pendingBlobs() -> [RemoteBlob] {
        let entries = store.all()
        guard let stamp = stamps.pendingStamp(newestEntry: entries.map(\.updatedAt).max()) else { return [] }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(entries) else { return [] }
        return [RemoteBlob(id: C.blobId, data: data, updatedAt: stamp)]
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        guard let blob = blobs.first(where: { $0.id == C.blobId }) else { return }
        stamps.markPushed(blob.updatedAt)
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        guard blob.id == C.blobId, let remote = try? JSONDecoder().decode([ExerciseFeedback].self, from: blob.data) else { return false }
        let changed = store.merge(remote)
        let remoteById = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let localHasExtra = store.all().contains { remoteById[$0.id] != $0 }
        stamps.noteRemote(stamp: blob.updatedAt, localHasExtra: localHasExtra)
        return changed
    }
}
