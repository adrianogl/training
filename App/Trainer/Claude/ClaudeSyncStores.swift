import CryptoKit
import Foundation
import RemoteSync

struct ClaudeContextSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    nonisolated(unsafe) let defaults: UserDefaults

    func handles(_ id: String) -> Bool {
        id == ClaudeConstants.contextBlobId
    }

    func pendingBlobs() -> [RemoteBlob] {
        guard let outbox = ClaudeMailbox(defaults: defaults).outbox() else { return [] }
        if let synced = defaults.object(forKey: ClaudeConstants.contextSyncedKey) as? Date, synced >= outbox.stamp { return [] }
        return [RemoteBlob(id: ClaudeConstants.contextBlobId, data: outbox.data, updatedAt: outbox.stamp)]
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {
        guard let blob = blobs.first(where: { $0.id == ClaudeConstants.contextBlobId }) else { return }
        defaults.set(blob.updatedAt, forKey: ClaudeConstants.contextSyncedKey)
    }

    func apply(_ blob: RemoteBlob) -> Bool {
        false
    }
}

struct ClaudeInboxSyncStore: RemoteBlobStore {
    let kind = RemoteRecordKind.preference
    nonisolated(unsafe) let defaults: UserDefaults

    func handles(_ id: String) -> Bool {
        id == ClaudeConstants.inboxBlobId
    }

    func pendingBlobs() -> [RemoteBlob] {
        []
    }

    func markBlobsPushed(_ blobs: [RemoteBlob]) {}

    func apply(_ blob: RemoteBlob) -> Bool {
        guard blob.id == ClaudeConstants.inboxBlobId,
              let envelope = try? JSONDecoder().decode(ClaudeInboxEnvelope.self, from: blob.data) else { return false }
        let mailbox = ClaudeMailbox(defaults: defaults)
        if let current = mailbox.inbox(), current.savedAt >= blob.updatedAt { return false }
        mailbox.receive(ClaudeInbox(json: envelope.json, savedAt: blob.updatedAt))
        return true
    }
}

struct ClaudeMailbox {
    var defaults: UserDefaults = AccountScope.current.defaults

    func outbox() -> ClaudeOutbox? {
        defaults.data(forKey: ClaudeConstants.outboxKey).flatMap { try? JSONDecoder().decode(ClaudeOutbox.self, from: $0) }
    }

    @discardableResult
    func publish(_ envelope: ClaudeContextEnvelope, now: Date = .now) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let context = try? encoder.encode(envelope.contexto), let data = try? encoder.encode(envelope) else { return false }
        let signature = SHA256.hash(data: Data(envelope.texto.utf8) + context).map { String(format: "%02x", $0) }.joined()
        if outbox()?.signature == signature { return false }
        guard let outbox = try? JSONEncoder().encode(ClaudeOutbox(data: data, stamp: now, signature: signature)) else { return false }
        defaults.set(outbox, forKey: ClaudeConstants.outboxKey)
        return true
    }

    func inbox() -> ClaudeInbox? {
        defaults.data(forKey: ClaudeConstants.inboxKey).flatMap { try? JSONDecoder().decode(ClaudeInbox.self, from: $0) }
    }

    func receive(_ inbox: ClaudeInbox) {
        defaults.set(try? JSONEncoder().encode(inbox), forKey: ClaudeConstants.inboxKey)
    }

    func unseen() -> ClaudeInbox? {
        guard let inbox = inbox() else { return nil }
        if let seen = defaults.object(forKey: ClaudeConstants.inboxSeenKey) as? Date, seen >= inbox.savedAt { return nil }
        return inbox
    }

    func markSeen(_ inbox: ClaudeInbox) {
        defaults.set(inbox.savedAt, forKey: ClaudeConstants.inboxSeenKey)
    }
}
