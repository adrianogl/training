import CryptoKit
import Foundation
import Metrics
import Storage
import SwiftData

public actor RemoteSyncEngine {
    private typealias C = RemoteSyncConstants
    private let container: ModelContainer
    private let client: RemoteClient
    private let key: SymmetricKey?
    private let now: @Sendable () -> Date
    private let defaultsSuite: String?
    private let trainerStore: (any RemoteTrainerStore)?
    private let narrativeStore: (any RemoteNarrativeStore)?
    private let blobStores: [any RemoteBlobStore]
    private var current: Task<RemoteSyncReport, any Error>?

    public init(container: ModelContainer, client: RemoteClient, keys: RemoteKeys? = nil, defaultsSuite: String? = nil, trainerStore: (any RemoteTrainerStore)? = nil, narrativeStore: (any RemoteNarrativeStore)? = nil, blobStores: [any RemoteBlobStore] = [], now: @escaping @Sendable () -> Date = { .now }) {
        self.container = container
        self.client = client
        self.key = keys?.payload
        self.defaultsSuite = defaultsSuite
        self.trainerStore = trainerStore
        self.narrativeStore = narrativeStore
        self.blobStores = blobStores
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
        let defaults = defaultsSuite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        let migrated = defaults.bool(forKey: C.plainMigrationKey)
        let lastPush = migrated ? Self.syncState(in: snapshot)?.remoteLastPush : nil
        let cursor = Self.syncState(in: snapshot)?.remoteCursor ?? 0
        var outgoing = try pendingRecords(since: lastPush, in: snapshot)
        let trainerMigrated = defaults.bool(forKey: C.trainerPlainMigrationKey)
        if !trainerMigrated { trainerStore?.markPending() }
        let trainerPending = trainerStore?.pending()
        if let trainerPending {
            if let record = try trainerRecord(trainerPending) {
                outgoing.records.append(record)
            } else {
                outgoing.tooLarge.append(RemoteRecordKey(kind: .trainer, id: C.trainerRecordId))
            }
        }
        let narratives = narrativeStore?.pendingNarratives() ?? []
        for narrative in narratives {
            outgoing.records.append(RemoteRecord(
                kind: .narrative, id: narrative.id, updatedAt: narrative.updatedAt, deleted: false,
                payload: try RemotePayload.plain(blob: Data(narrative.text.utf8)), format: .plain
            ))
        }
        let blobs = blobStores.map { store in (store, store.pendingBlobs()) }
        for (store, pending) in blobs {
            for blob in pending {
                let payload = try RemotePayload.plain(blob: blob.data)
                if payload.utf8.count <= C.maxPayloadCharacters {
                    outgoing.records.append(RemoteRecord(kind: store.kind, id: blob.id, updatedAt: blob.updatedAt, deleted: false, payload: payload, format: .plain))
                } else {
                    outgoing.tooLarge.append(RemoteRecordKey(kind: store.kind, id: blob.id))
                }
            }
        }
        let push = try await pushAll(outgoing.records)
        let pages = try await pullAll(since: cursor)

        let context = ModelContext(container)
        if let trainerPending, push.accepted.contains(RemoteRecordKey(kind: .trainer, id: C.trainerRecordId)) {
            trainerStore?.markPushed(updatedAt: trainerPending.updatedAt)
        }
        narrativeStore?.markNarrativesPushed(narratives.filter { push.accepted.contains(RemoteRecordKey(kind: .narrative, id: $0.id)) })
        for (store, pending) in blobs {
            store.markBlobsPushed(pending.filter { push.accepted.contains(RemoteRecordKey(kind: store.kind, id: $0.id)) })
        }
        var changedKinds: Set<RemoteRecordKind> = []
        var applied = 0
        var trainerChanged = false
        var narrativesChanged = false
        for record in pages.records {
            if record.format != .plain, key == nil, record.payload != nil { continue }
            if record.kind == .trainer {
                if try applyTrainer(record) {
                    applied += 1
                    trainerChanged = true
                }
            } else if let store = blobStores.first(where: { $0.kind == record.kind && $0.handles(record.id) }) {
                if try applyBlob(record, store: store) {
                    applied += 1
                    changedKinds.insert(record.kind)
                }
            } else if record.kind == .narrative {
                if try applyNarrative(record) {
                    applied += 1
                    narrativesChanged = true
                }
            } else if try apply(record, in: context) {
                applied += 1
            }
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
        if !push.quotaExceeded { defaults.set(true, forKey: C.plainMigrationKey) }
        if !push.quotaExceeded, trainerStore != nil, trainerPending == nil || push.accepted.contains(RemoteRecordKey(kind: .trainer, id: C.trainerRecordId)) {
            defaults.set(true, forKey: C.trainerPlainMigrationKey)
        }
        return RemoteSyncReport(
            pushed: push.count,
            pulled: pages.records.count,
            applied: applied,
            tooLarge: outgoing.tooLarge + push.rejected,
            quotaExceeded: push.quotaExceeded,
            trainerChanged: trainerChanged,
            narrativesChanged: narrativesChanged,
            changedKinds: changedKinds
        )
    }

    private func pushAll(_ records: [RemoteRecord]) async throws -> (accepted: Set<RemoteRecordKey>, count: Int, rejected: [RemoteRecordKey], confirmedTombstones: [RemoteRecordKey], quotaExceeded: Bool) {
        var accepted: Set<RemoteRecordKey> = []
        var count = 0
        var rejected: [RemoteRecordKey] = []
        var confirmed: [RemoteRecordKey] = []
        func record(_ sent: [RemoteRecord], ignored: Set<RemoteRecordKey>) {
            count += sent.count
            accepted.formUnion(sent.map(Self.key))
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
            return (accepted, count, rejected, confirmed, true)
        }
        return (accepted, count, rejected, confirmed, false)
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
        let goals = try context.fetch(FetchDescriptor<GoalRecord>(predicate: #Predicate { $0.updatedAt > after }))
        var records: [RemoteRecord] = []
        var tooLarge: [RemoteRecordKey] = []
        for race in races {
            let id = race.id.uuidString
            guard race.deletedAt == nil else {
                records.append(RemoteRecord(kind: .race, id: id, updatedAt: race.updatedAt, deleted: true, payload: nil, format: .plain))
                continue
            }
            guard let payload = try racePayload(race) else {
                tooLarge.append(RemoteRecordKey(kind: .race, id: id))
                continue
            }
            records.append(RemoteRecord(kind: .race, id: id, updatedAt: race.updatedAt, deleted: false, payload: payload, format: .plain))
        }
        for decision in decisions {
            let deleted = decision.deletedAt != nil
            records.append(RemoteRecord(
                kind: .decision, id: String(decision.activityId), updatedAt: decision.updatedAt, deleted: deleted,
                payload: deleted ? nil : try RemotePayload.plain(decision: decision), format: .plain
            ))
        }
        for goal in goals {
            let deleted = goal.deletedAt != nil
            records.append(RemoteRecord(
                kind: .goal, id: goal.id.uuidString, updatedAt: goal.updatedAt, deleted: deleted,
                payload: deleted ? nil : try RemotePayload.plain(goal: GoalTransferItem(goal)), format: .plain
            ))
        }
        return (records, tooLarge)
    }

    private func trainerRecord(_ state: RemoteTrainerState) throws -> RemoteRecord? {
        guard let data = state.data else {
            return RemoteRecord(kind: .trainer, id: C.trainerRecordId, updatedAt: state.updatedAt, deleted: true, payload: nil, format: .plain)
        }
        let payload = try RemotePayload.plain(trainer: data)
        guard payload.utf8.count <= C.maxPayloadCharacters else { return nil }
        return RemoteRecord(kind: .trainer, id: C.trainerRecordId, updatedAt: state.updatedAt, deleted: false, payload: payload, format: .plain)
    }

    private func applyTrainer(_ record: RemoteRecord) throws -> Bool {
        guard let trainerStore, record.id == C.trainerRecordId else { return false }
        switch RemoteMerge.action(remoteUpdatedAt: record.updatedAt, remoteDeleted: record.deleted, localUpdatedAt: trainerStore.updatedAt()) {
        case .insert, .replace:
            guard let payload = record.payload else { throw RemoteSyncError.decoding }
            let data = record.format == .plain ? Data(payload.utf8) : try RemotePayload.openTrainer(payload, id: record.id, key: try sealKey())
            return trainerStore.apply(RemoteTrainerState(data: data, updatedAt: record.updatedAt))
        case .delete:
            return trainerStore.apply(RemoteTrainerState(data: nil, updatedAt: record.updatedAt))
        case .keepLocal, .ignore:
            return false
        }
    }

    private func sealKey() throws -> SymmetricKey {
        guard let key else { throw RemoteSyncError.tamperedPayload }
        return key
    }

    private func applyBlob(_ record: RemoteRecord, store: any RemoteBlobStore) throws -> Bool {
        guard !record.deleted, let payload = record.payload else { return false }
        let data = record.format == .plain ? try RemotePayload.decodeBlob(payload) : try RemotePayload.openBlob(payload, kind: record.kind, id: record.id, key: try sealKey())
        return store.apply(RemoteBlob(id: record.id, data: data, updatedAt: record.updatedAt))
    }

    private func applyNarrative(_ record: RemoteRecord) throws -> Bool {
        guard let narrativeStore else { return false }
        switch RemoteMerge.action(remoteUpdatedAt: record.updatedAt, remoteDeleted: record.deleted, localUpdatedAt: narrativeStore.narrativeUpdatedAt(id: record.id)) {
        case .insert, .replace:
            guard let payload = record.payload else { throw RemoteSyncError.decoding }
            let text = record.format == .plain
                ? String(decoding: try RemotePayload.decodeBlob(payload), as: UTF8.self)
                : try RemotePayload.openNarrative(payload, id: record.id, key: try sealKey())
            return narrativeStore.apply(RemoteNarrative(id: record.id, text: text, updatedAt: record.updatedAt))
        case .delete, .keepLocal, .ignore:
            return false
        }
    }

    private func racePayload(_ race: RaceRecord) throws -> String? {
        var item = RaceTransferItem(race)
        let payload = try RemotePayload.plain(race: item)
        if payload.utf8.count <= C.maxPayloadCharacters { return payload }
        guard let gpx = item.gpxData, let reduced = try? reducedGPX(gpx, maxPoints: C.reducedGPXMaxPoints) else { return nil }
        item.gpxData = reduced
        let smaller = try RemotePayload.plain(race: item)
        return smaller.utf8.count <= C.maxPayloadCharacters ? smaller : nil
    }

    private func apply(_ record: RemoteRecord, in context: ModelContext) throws -> Bool {
        switch record.kind {
        case .trainer, .narrative, .preference, .chat: false
        case .race: try applyRace(record, in: context)
        case .decision: try applyDecision(record, in: context)
        case .goal: try applyGoal(record, in: context)
        }
    }

    private func applyGoal(_ record: RemoteRecord, in context: ModelContext) throws -> Bool {
        guard let id = UUID(uuidString: record.id) else { throw RemoteSyncError.decoding }
        let local = try Self.goal(id, in: context)
        if record.deleted, let local, local.deletedAt != nil {
            context.delete(local)
            return false
        }
        switch RemoteMerge.action(remoteUpdatedAt: record.updatedAt, remoteDeleted: record.deleted, localUpdatedAt: local?.updatedAt) {
        case .insert:
            var item = try openGoal(record)
            item.id = id
            context.insert(item.makeRecord())
        case .replace:
            guard let local else { return false }
            try openGoal(record).apply(to: local)
        case .delete:
            guard let local else { return false }
            context.delete(local)
        case .keepLocal, .ignore:
            return false
        }
        return true
    }

    private func openGoal(_ record: RemoteRecord) throws -> GoalTransferItem {
        guard let payload = record.payload else { throw RemoteSyncError.decoding }
        var item = record.format == .plain ? try RemotePayload.decodeGoal(payload) : try RemotePayload.openGoal(payload, id: record.id, key: try sealKey())
        item.updatedAt = record.updatedAt
        return item
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
        var item = record.format == .plain ? try RemotePayload.decodeRace(payload) : try RemotePayload.openRace(payload, id: record.id, key: try sealKey())
        item.updatedAt = record.updatedAt
        return item
    }

    private func openDecision(_ record: RemoteRecord) throws -> RaceDecision {
        guard let payload = record.payload,
              let decision = RaceDecision(rawValue: try (record.format == .plain ? RemotePayload.decodeDecision(payload) : RemotePayload.openDecision(payload, id: record.id, key: try sealKey())).decision)
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
        case .goal:
            guard let id = UUID(uuidString: key.id), let local = try Self.goal(id, in: context), local.deletedAt != nil else { return }
            context.delete(local)
        case .trainer, .narrative, .preference, .chat:
            return
        }
    }

    private static func race(_ id: UUID, in context: ModelContext) throws -> RaceRecord? {
        var descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func goal(_ id: UUID, in context: ModelContext) throws -> GoalRecord? {
        var descriptor = FetchDescriptor<GoalRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func decision(_ activityId: Int64, in context: ModelContext) throws -> RaceDecisionRecord? {
        var descriptor = FetchDescriptor<RaceDecisionRecord>(predicate: #Predicate { $0.activityId == activityId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
