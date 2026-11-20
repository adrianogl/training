import Foundation
import RemoteSync

struct StrengthPlanSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    let store: StrengthPlanStore
    nonisolated(unsafe) let defaults: UserDefaults

    private typealias C = StrengthPlanStoreConstants

    private var stamps: SyncDocumentStamp {
        SyncDocumentStamp(defaults: defaults, syncedKey: C.syncedStampKey, documentKey: C.documentStampKey)
    }

    func handles(_ id: String) -> Bool {
        id == C.blobId
    }

    func pendingBlobs() -> [RemoteBlob] {
        let doc = store.document()
        guard doc.updatedAt > .distantPast,
              let stamp = stamps.pendingStamp(newestEntry: doc.updatedAt) else { return [] }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(doc) else { return [] }
        return [RemoteBlob(id: C.blobId, data: data, updatedAt: stamp)]
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        guard let blob = blobs.first(where: { $0.id == C.blobId }) else { return }
        stamps.markPushed(blob.updatedAt)
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        guard blob.id == C.blobId, let remote = try? JSONDecoder().decode(StrengthPlanDocument.self, from: blob.data) else { return false }
        let changed = store.merge(remote: remote)
        stamps.reconcile(remote: [remote], local: [store.document()], remoteStamp: blob.updatedAt)
        return changed
    }
}
