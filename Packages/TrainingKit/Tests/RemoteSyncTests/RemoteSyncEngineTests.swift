import Foundation
import Storage
import SwiftData
import Testing
@testable import RemoteSync

private let keys = try! RemoteKeys(syncKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")
private let base = Date(timeIntervalSince1970: 1_800_000_000)
private let syncTime = base.addingTimeInterval(3_600)

private struct Harness {
    let container: ModelContainer
    let transport: ScriptedTransport
    let engine: RemoteSyncEngine

    var context: ModelContext { ModelContext(container) }

    func races() throws -> [RaceRecord] { try context.fetch(FetchDescriptor<RaceRecord>()) }
    func decisions() throws -> [RaceDecisionRecord] { try context.fetch(FetchDescriptor<RaceDecisionRecord>()) }
    func state() throws -> SyncState? { try context.fetch(FetchDescriptor<SyncState>()).first }
}

private func harness(_ responses: [ScriptedTransport.Response], setup: (ModelContext) -> Void = { _ in }) throws -> Harness {
    let container = try TrainingSchema.container(inMemory: true)
    let context = ModelContext(container)
    setup(context)
    try context.save()
    let transport = ScriptedTransport(responses)
    let client = RemoteClient(baseURL: URL(string: "https://sync.example.test")!, keys: keys, transport: transport)
    let engine = RemoteSyncEngine(container: container, client: client, keys: keys, now: { syncTime })
    return Harness(container: container, transport: transport, engine: engine)
}

private func page(_ records: [RemoteRecord], cursor: Int64, hasMore: Bool = false) -> ScriptedTransport.Response {
    let encoded = try! RemoteJSON.encoder().encode(records)
    return .json(200, #"{"records":\#(String(data: encoded, encoding: .utf8)!),"cursor":\#(cursor),"hasMore":\#(hasMore)}"#)
}

private func pushed(cursor: Int64, ignored: [RemoteRecordKey] = []) -> ScriptedTransport.Response {
    let encoded = try! JSONEncoder().encode(ignored)
    return .json(200, #"{"cursor":\#(cursor),"ignored":\#(String(data: encoded, encoding: .utf8)!)}"#)
}

private func remoteRace(_ race: RaceRecord, seq: Int64) -> RemoteRecord {
    RemoteRecord(kind: .race, id: race.id.uuidString, updatedAt: race.updatedAt, deleted: false, payload: try! RemotePayload.seal(race: race, key: keys.payload), seq: seq)
}

private func remoteTombstone(_ kind: RemoteRecordKind, id: String, updatedAt: Date, seq: Int64) -> RemoteRecord {
    RemoteRecord(kind: kind, id: id, updatedAt: updatedAt, deleted: true, payload: nil, seq: seq)
}

@Suite struct RemoteSyncEngineTests {
    @Test func pushesOnlyWhatChangedSinceLastPush() async throws {
        let old = RaceRecord(name: "Antiga", day: "2026-10-01", distance: 10_000, updatedAt: base.addingTimeInterval(-10))
        let edited = RaceRecord(name: "Editada", day: "2026-12-01", distance: 21_097.5, updatedAt: base.addingTimeInterval(10))
        let deleted = RaceRecord(name: "Apagada", day: "2026-11-01", distance: 5_000, updatedAt: base.addingTimeInterval(20), deletedAt: base.addingTimeInterval(20))
        let h = try harness([pushed(cursor: 4), page([], cursor: 4)]) { context in
            context.insert(SyncState(remoteCursor: 1, remoteLastPush: base))
            [old, edited, deleted].forEach(context.insert)
            context.insert(RaceDecisionRecord(activityId: 55, decision: .notRace, updatedAt: base.addingTimeInterval(5)))
            context.insert(RaceDecisionRecord(activityId: 56, decision: .race, updatedAt: base.addingTimeInterval(-5)))
        }

        let report = try await h.engine.sync()

        let bodies = h.transport.pushBodies
        #expect(bodies.count == 1)
        let records = try #require(bodies.first)
        #expect(Set(records.compactMap { $0["id"] as? String }) == [edited.id.uuidString, deleted.id.uuidString, "55"])
        let tombstone = try #require(records.first { $0["id"] as? String == deleted.id.uuidString })
        #expect(tombstone["deleted"] as? Bool == true)
        #expect(tombstone["payload"] is NSNull)
        let live = try #require(records.first { $0["id"] as? String == edited.id.uuidString })
        let item = try RemotePayload.openRace(try #require(live["payload"] as? String), id: edited.id.uuidString, key: keys.payload)
        #expect(item.name == "Editada")
        #expect(live["updatedAt"] as? String == RemoteTimestamp.string(from: edited.updatedAt))
        let decision = try #require(records.first { $0["id"] as? String == "55" })
        #expect(try RemotePayload.openDecision(try #require(decision["payload"] as? String), id: "55", key: keys.payload) == RemoteDecisionPayload(activityId: 55, decision: "notRace"))
        #expect(h.transport.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer \(keys.bearer)" })
        #expect(h.transport.requests.last?.url?.query == "since=1")
        #expect(report == RemoteSyncReport(pushed: 3, pulled: 0, applied: 0))
        #expect(Set(try h.races().map(\.name)) == ["Antiga", "Editada"])
        let state = try #require(try h.state())
        #expect(state.remoteCursor == 4)
        #expect(state.remoteLastPush == syncTime)
    }

    @Test func pushesInBatchesOfOneHundred() async throws {
        let h = try harness([pushed(cursor: 100), pushed(cursor: 200), pushed(cursor: 205), page([], cursor: 205)]) { context in
            for id in 1...205 {
                context.insert(RaceDecisionRecord(activityId: Int64(id), decision: .race, updatedAt: base))
            }
        }

        let report = try await h.engine.sync()

        #expect(h.transport.pushBodies.map(\.count) == [100, 100, 5])
        #expect(report.pushed == 205)
        #expect(try h.state()?.remoteCursor == 205)
    }

    @Test func pullPaginatesAppliesAndAdvancesCursor() async throws {
        let race = RaceRecord(name: "Do iPad", day: "2026-12-10", distance: 42_195, goalSeconds: 14_400, priority: .a, updatedAt: base)
        let decision = RaceDecisionRecord(activityId: 77, decision: .notRace, updatedAt: base)
        let decisionRecord = RemoteRecord(kind: .decision, id: "77", updatedAt: base, deleted: false, payload: try RemotePayload.seal(decision: decision, key: keys.payload), seq: 12)
        let h = try harness([
            page([remoteRace(race, seq: 11)], cursor: 11, hasMore: true),
            page([decisionRecord], cursor: 12),
        ]) { context in
            context.insert(SyncState(remoteCursor: 10, remoteLastPush: base))
        }

        let report = try await h.engine.sync()

        #expect(h.transport.pushBodies.isEmpty)
        #expect(h.transport.requests.map { $0.url?.query } == ["since=10", "since=11"])
        let stored = try #require(try h.races().first)
        #expect(stored.id == race.id)
        #expect(stored.name == "Do iPad")
        #expect(stored.priorityLevel == .a)
        #expect(stored.goalSeconds == 14_400)
        #expect(RemoteTimestamp.milliseconds(stored.updatedAt) == RemoteTimestamp.milliseconds(base))
        #expect(stored.deletedAt == nil)
        let storedDecision = try #require(try h.decisions().first)
        #expect(storedDecision.activityId == 77)
        #expect(storedDecision.raceDecision == .notRace)
        #expect(report == RemoteSyncReport(pushed: 0, pulled: 2, applied: 2))
        #expect(try h.state()?.remoteCursor == 12)
    }

    @Test func newerSideWinsConflicts() async throws {
        let id = UUID()
        let keptId = UUID()
        let local = RaceRecord(id: id, name: "Local velha", day: "2026-12-01", distance: 10_000, updatedAt: base)
        let keptLocal = RaceRecord(id: keptId, name: "Local nova", day: "2026-12-02", distance: 10_000, updatedAt: base.addingTimeInterval(60))
        let remoteNewer = RaceRecord(id: id, name: "Remota nova", day: "2026-12-05", distance: 21_097.5, updatedAt: base.addingTimeInterval(1))
        let remoteOlder = RaceRecord(id: keptId, name: "Remota velha", day: "2026-12-02", distance: 10_000, updatedAt: base.addingTimeInterval(30))
        let h = try harness([page([remoteRace(remoteNewer, seq: 1), remoteRace(remoteOlder, seq: 2)], cursor: 2)]) { context in
            context.insert(SyncState(remoteLastPush: base.addingTimeInterval(120)))
            context.insert(local)
            context.insert(keptLocal)
        }

        let report = try await h.engine.sync()

        let races = Dictionary(uniqueKeysWithValues: try h.races().map { ($0.id, $0) })
        #expect(races[id]?.name == "Remota nova")
        #expect(races[id]?.day == "2026-12-05")
        #expect(races[keptId]?.name == "Local nova")
        #expect(report.applied == 1)
    }

    @Test func remoteTombstoneRemovesLocalRecord() async throws {
        let race = RaceRecord(name: "Vai sumir", day: "2026-12-01", distance: 10_000, updatedAt: base)
        let h = try harness([page([
            remoteTombstone(.race, id: race.id.uuidString, updatedAt: base.addingTimeInterval(5), seq: 1),
            remoteTombstone(.decision, id: "88", updatedAt: base.addingTimeInterval(5), seq: 2),
            remoteTombstone(.race, id: UUID().uuidString, updatedAt: base, seq: 3),
        ], cursor: 3)]) { context in
            context.insert(SyncState(remoteLastPush: base.addingTimeInterval(60)))
            context.insert(race)
            context.insert(RaceDecisionRecord(activityId: 88, decision: .race, updatedAt: base))
        }

        try await h.engine.sync()

        #expect(try h.races().isEmpty)
        #expect(try h.decisions().isEmpty)
    }

    @Test func tombstoneIgnoredByServerStaysUntilNewerVersionArrives() async throws {
        let race = RaceRecord(name: "Apagada aqui", day: "2026-12-01", distance: 10_000, updatedAt: base, deletedAt: base)
        let newer = RaceRecord(id: race.id, name: "Editada no iPad", day: "2026-12-01", distance: 10_000, updatedAt: base.addingTimeInterval(10))
        let h = try harness([
            pushed(cursor: 3, ignored: [RemoteRecordKey(kind: .race, id: race.id.uuidString)]),
            page([remoteRace(newer, seq: 3)], cursor: 3),
        ]) { context in
            context.insert(race)
        }

        try await h.engine.sync()

        let stored = try #require(try h.races().first)
        #expect(stored.name == "Editada no iPad")
        #expect(stored.deletedAt == nil)
    }

    @Test func unauthorizedIsTypedAndMarksNothing() async throws {
        let h = try harness([.json(401, #"{"error":"unknown account"}"#)]) { context in
            context.insert(RaceRecord(name: "Pendente", day: "2026-12-01", distance: 10_000, updatedAt: base))
        }

        await #expect(throws: RemoteSyncError.unauthorized) { try await h.engine.sync() }

        #expect(try h.state()?.remoteLastPush == nil)
        #expect(try h.state()?.remoteCursor ?? 0 == 0)
    }

    @Test func networkFailureOnPushKeepsTombstoneAndPending() async throws {
        let deleted = RaceRecord(name: "Apagada", day: "2026-12-01", distance: 10_000, updatedAt: base, deletedAt: base)
        let h = try harness([.failure(.notConnectedToInternet)]) { context in
            context.insert(SyncState(remoteCursor: 7, remoteLastPush: base.addingTimeInterval(-60)))
            context.insert(deleted)
        }

        await #expect(throws: URLError.self) { try await h.engine.sync() }

        #expect(try h.races().first?.deletedAt != nil)
        #expect(try h.state()?.remoteLastPush == base.addingTimeInterval(-60))
        #expect(try h.state()?.remoteCursor == 7)
    }

    @Test func failureMidPullDoesNotAdvanceCursorNorKeepPartialPages() async throws {
        let race = RaceRecord(name: "Página um", day: "2026-12-01", distance: 10_000, updatedAt: base)
        let h = try harness([
            page([remoteRace(race, seq: 21)], cursor: 21, hasMore: true),
            .failure(.timedOut),
        ]) { context in
            context.insert(SyncState(remoteCursor: 20, remoteLastPush: base))
        }

        await #expect(throws: URLError.self) { try await h.engine.sync() }

        #expect(try h.races().isEmpty)
        #expect(try h.state()?.remoteCursor == 20)
        #expect(try h.state()?.remoteLastPush == base)
    }

    @Test func tamperedRemotePayloadFailsWithoutAdvancing() async throws {
        let bad = RemoteRecord(kind: .race, id: UUID().uuidString, updatedAt: base, deleted: false, payload: Data("adulterado".utf8).base64EncodedString(), seq: 1)
        let h = try harness([page([bad], cursor: 1)]) { context in
            context.insert(SyncState(remoteLastPush: base))
        }

        await #expect(throws: RemoteSyncError.tamperedPayload) { try await h.engine.sync() }

        #expect(try h.state()?.remoteCursor == 0)
    }

    @Test func ownEchoInPullKeepsLocalAndPurgesAcceptedTombstone() async throws {
        let live = RaceRecord(name: "Minha", day: "2026-12-01", distance: 10_000, updatedAt: base.addingTimeInterval(0.0004))
        let deleted = RaceRecord(name: "Apagada", day: "2026-12-02", distance: 10_000, updatedAt: base, deletedAt: base)
        let echo = RaceRecord(id: live.id, name: "Minha", day: "2026-12-01", distance: 10_000, updatedAt: base)
        let h = try harness([
            pushed(cursor: 2),
            page([remoteRace(echo, seq: 1), remoteTombstone(.race, id: deleted.id.uuidString, updatedAt: base, seq: 2)], cursor: 2),
        ]) { context in
            context.insert(live)
            context.insert(deleted)
        }

        let report = try await h.engine.sync()

        #expect(try h.races().map(\.name) == ["Minha"])
        #expect(report.applied == 0)
    }
}
