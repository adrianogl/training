import CryptoKit
import Foundation
import Metrics
import Storage
import SwiftData

public actor RemoteSyncEngine {
    private typealias C = RemoteSyncConstants
    private let container: ModelContainer
    private let client: RemoteClient
    private let key: SymmetricKey
    private let now: @Sendable () -> Date
    private var current: Task<RemoteSyncReport, any Error>?

    public init(container: ModelContainer, client: RemoteClient, keys: RemoteKeys, now: @escaping @Sendable () -> Date = { .now }) {
        self.container = container
        self.client = client
        self.key = keys.payload
        self.now = now
    }

    @discardableResult
    public func sync() async throws -> RemoteSyncReport {
        let previous = current
        let task = Task {
            _ = try? await previous?.value
            return try await run()
        }
        current = task
        return try await task.value
    }

    private func run() async throws -> RemoteSyncReport {
        let startedAt = now()
        let snapshot = ModelContext(container)
        let lastPush = Self.syncState(in: snapshot)?.remoteLastPush
        let cursor = Self.syncState(in: snapshot)?.remoteCursor ?? 0
        let outgoing = try pendingRecords(since: lastPush, in: snapshot)
        let push = try await pushAll(outgoing.records)
        let pages = try await pullAll(since: cursor)

        let context = ModelContext(container)
        var applied = 0
        for record in pages.records {
            if try apply(record, in: context) { applied += 1 }
        }
        for key in push.confirmedTombstones {
            try purgeTombstone(key, in: context)
        }
        let state = Self.syncState(in: context) ?? {
            let created = SyncState()
            context.insert(created)
            return created
        }()
        state.remoteCursor = pages.cursor
        if !push.quotaExceeded { state.remoteLastPush = startedAt }
        try context.save()
        return RemoteSyncReport(
            pushed: push.accepted,
            pulled: pages.records.count,
            applied: applied,
            tooLarge: outgoing.tooLarge + push.rejected,
            quotaExceeded: push.quotaExceeded
        )
    }

    private func pushAll(_ records: [RemoteRecord]) async throws -> (accepted: Int, rejected: [RemoteRecordKey], confirmedTombstones: [RemoteRecordKey], quotaExceeded: Bool) {
        var accepted = 0
        var rejected: [RemoteRecordKey] = []
        var confirmed: [RemoteRecordKey] = []
        func record(_ sent: [RemoteRecord], ignored: Set<RemoteRecordKey>) {
            accepted += sent.count
            confirmed += sent.filter { $0.deleted && !ignored.contains(Self.key($0)) }.map(Self.key)
        }
        do {
            for batch in try Self.batches(records) {
                do {
                    record(batch, ignored: Set(try await client.push(batch).ignored))
                } catch RemoteSyncError.badRequest, RemoteSyncError.payloadTooLarge {
                    for single in batch {
                        do {
                            record([single], ignored: Set(try await client.push([single]).ignored))
                        } catch RemoteSyncError.badRequest, RemoteSyncError.payloadTooLarge {
                            rejected.append(Self.key(single))
                        }
                    }
                }
            }
        } catch RemoteSyncError.quotaExceeded {
            return (accepted, rejected, confirmed, true)
        }
        return (accepted, rejected, confirmed, false)
    }

    private func pullAll(since start: Int64) async throws -> (records: [RemoteRecord], cursor: Int64) {
        var cursor = start
        var records: [RemoteRecord] = []
        while true {
            let page = try await client.changes(since: cursor)
            records += page.records
            guard page.hasMore else { return (records, page.cursor) }
            guard page.cursor > cursor else { throw RemoteSyncError.decoding }
            cursor = page.cursor
        }
    }

    private static func batches(_ records: [RemoteRecord]) throws -> [[RemoteRecord]] {
        let encoder = RemoteJSON.encoder()
        var result: [[RemoteRecord]] = []
        var batch: [RemoteRecord] = []
        var bytes = 0
        for record in records {
            let size = try encoder.encode(record).count + 1
            if !batch.isEmpty, batch.count == C.pushBatchSize || bytes + size > C.maxBatchBodyBytes - C.batchEnvelopeBytes {
                result.append(batch)
                batch = []
                bytes = 0
            }
            batch.append(record)
            bytes += size
        }
        if !batch.isEmpty { result.append(batch) }
        return result
    }

    private static func key(_ record: RemoteRecord) -> RemoteRecordKey {
        RemoteRecordKey(kind: record.kind, id: record.id)
    }

    private static func syncState(in context: ModelContext) -> SyncState? {
        ((try? context.fetch(FetchDescriptor<SyncState>())) ?? []).sorted { a, b in
            if a.firstLoadCompleted != b.firstLoadCompleted { return a.firstLoadCompleted }
            return (a.lastSync ?? .distantPast) > (b.lastSync ?? .distantPast)
        }.first
    }

    private func pendingRecords(since lastPush: Date?, in context: ModelContext) throws -> (records: [RemoteRecord], tooLarge: [RemoteRecordKey]) {
        let after = lastPush.map { $0.addingTimeInterval(-C.pushOverlap) } ?? .distantPast
        let races = try context.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.updatedAt > after }))
        let decisions = try context.fetch(FetchDescriptor<RaceDecisionRecord>(predicate: #Predicate { $0.updatedAt > after }))
        var records: [RemoteRecord] = []
        var tooLarge: [RemoteRecordKey] = []
        for race in races {
            let id = race.id.uuidString
            guard race.deletedAt == nil else {
                records.append(RemoteRecord(kind: .race, id: id, updatedAt: race.updatedAt, deleted: true, payload: nil))
                continue
            }
            guard let payload = try racePayload(race) else {
                tooLarge.append(RemoteRecordKey(kind: .race, id: id))
                continue
            }
            records.append(RemoteRecord(kind: .race, id: id, updatedAt: race.updatedAt, deleted: false, payload: payload))
        }
        for decision in decisions {
            let deleted = decision.deletedAt != nil
            records.append(RemoteRecord(
                kind: .decision, id: String(decision.activityId), updatedAt: decision.updatedAt, deleted: deleted,
                payload: deleted ? nil : try RemotePayload.seal(decision: decision, key: key)
            ))
        }
        return (records, tooLarge)
    }

    private func racePayload(_ race: RaceRecord) throws -> String? {
        var item = RaceTransferItem(race)
        let payload = try RemotePayload.seal(race: item, key: key)
        if payload.utf8.count <= C.maxPayloadCharacters { return payload }
        guard let gpx = item.gpxData, let reduced = try? reducedGPX(gpx, maxPoints: C.reducedGPXMaxPoints) else { return nil }
        item.gpxData = reduced
        let smaller = try RemotePayload.seal(race: item, key: key)
        return smaller.utf8.count <= C.maxPayloadCharacters ? smaller : nil
    }

    private func apply(_ record: RemoteRecord, in context: ModelContext) throws -> Bool {
        switch record.kind {
        case .race: try applyRace(record, in: context)
        case .decision: try applyDecision(record, in: context)
        }
    }

    private func applyRace(_ record: RemoteRecord, in context: ModelContext) throws -> Bool {
        guard let id = UUID(uuidString: record.id) else { throw RemoteSyncError.decoding }
        let local = try Self.race(id, in: context)
        if record.deleted, let local, local.deletedAt != nil {
            context.delete(local)
            return false
        }
        switch RemoteMerge.action(remoteUpdatedAt: record.updatedAt, remoteDeleted: record.deleted, localUpdatedAt: local?.updatedAt) {
        case .insert:
            var item = try openRace(record)
            item.id = id
            context.insert(item.makeRecord())
        case .replace:
            guard let local else { return false }
            try openRace(record).apply(to: local)
        case .delete:
            guard let local else { return false }
            context.delete(local)
        case .keepLocal, .ignore:
            return false
        }
        return true
    }

    private func applyDecision(_ record: RemoteRecord, in context: ModelContext) throws -> Bool {
        guard let activityId = Int64(record.id) else { throw RemoteSyncError.decoding }
        let local = try Self.decision(activityId, in: context)
        if record.deleted, let local, local.deletedAt != nil {
            context.delete(local)
            return false
        }
        switch RemoteMerge.action(remoteUpdatedAt: record.updatedAt, remoteDeleted: record.deleted, localUpdatedAt: local?.updatedAt) {
        case .insert:
            context.insert(RaceDecisionRecord(activityId: activityId, decision: try openDecision(record), updatedAt: record.updatedAt))
        case .replace:
            guard let local else { return false }
            local.raceDecision = try openDecision(record)
            local.updatedAt = record.updatedAt
            local.deletedAt = nil
        case .delete:
            guard let local else { return false }
            context.delete(local)
        case .keepLocal, .ignore:
            return false
        }
        return true
    }

    private func openRace(_ record: RemoteRecord) throws -> RaceTransferItem {
        guard let payload = record.payload else { throw RemoteSyncError.decoding }
        var item = try RemotePayload.openRace(payload, id: record.id, key: key)
        item.updatedAt = record.updatedAt
        return item
    }

    private func openDecision(_ record: RemoteRecord) throws -> RaceDecision {
        guard let payload = record.payload,
              let decision = RaceDecision(rawValue: try RemotePayload.openDecision(payload, id: record.id, key: key).decision)
        else { throw RemoteSyncError.decoding }
        return decision
    }

    private func purgeTombstone(_ key: RemoteRecordKey, in context: ModelContext) throws {
        switch key.kind {
        case .race:
            guard let id = UUID(uuidString: key.id), let local = try Self.race(id, in: context), local.deletedAt != nil else { return }
            context.delete(local)
        case .decision:
            guard let activityId = Int64(key.id), let local = try Self.decision(activityId, in: context), local.deletedAt != nil else { return }
            context.delete(local)
        }
    }

    private static func race(_ id: UUID, in context: ModelContext) throws -> RaceRecord? {
        var descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func decision(_ activityId: Int64, in context: ModelContext) throws -> RaceDecisionRecord? {
        var descriptor = FetchDescriptor<RaceDecisionRecord>(predicate: #Predicate { $0.activityId == activityId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
