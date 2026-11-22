import Foundation
import RemoteSync

struct TrainerSendSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    nonisolated(unsafe) let defaults: UserDefaults

    private typealias C = TrainerSendConstants

    private var store: TrainerSendStore { TrainerSendStore(defaults: defaults) }

    private var stamps: SyncDocumentStamp {
        SyncDocumentStamp(defaults: defaults, syncedKey: C.ledgerSyncedStampKey, documentKey: C.ledgerDocumentStampKey)
    }

    func handles(_ id: String) -> Bool {
        id == C.ledgerBlobId
    }

    func pendingBlobs() -> [RemoteBlob] {
        let ledger = store.ledger()
        guard !ledger.entries.isEmpty || !ledger.orphans.isEmpty,
              let stamp = stamps.pendingStamp(newestEntry: ledger.updatedAt) else { return [] }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(ledger) else { return [] }
        return [RemoteBlob(id: C.ledgerBlobId, data: data, updatedAt: stamp)]
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        guard let blob = blobs.first(where: { $0.id == C.ledgerBlobId }) else { return }
        stamps.markPushed(blob.updatedAt)
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        guard blob.id == C.ledgerBlobId, let remote = try? JSONDecoder().decode(TrainerSendLedger.self, from: blob.data) else { return false }
        let before = store.ledger()
        let merged = store.merge(remote: remote)
        if merged == remote {
            stamps.markPushed(blob.updatedAt)
        } else {
            stamps.bumpForLocalChange(newestEntry: merged.updatedAt)
        }
        return merged != before
    }
}
