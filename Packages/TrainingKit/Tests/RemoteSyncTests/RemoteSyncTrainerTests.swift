import Foundation
import Storage
import SwiftData
import Synchronization
import Testing
@testable import RemoteSync

private let keys = try! RemoteKeys(syncKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")
private let base = Date(timeIntervalSince1970: 1_800_000_000)
private let plan = Data(#"{"name":"plano"}"#.utf8)
private let emptyPage = ScriptedTransport.Response.json(200, #"{"records":[],"cursor":1,"hasMore":false}"#)

private func accepted(ignored: String = "[]") -> ScriptedTransport.Response {
    .json(200, #"{"cursor":1,"ignored":\#(ignored)}"#)
}

private final class FakeTrainerStore: RemoteTrainerStore {
    private struct State {
        var data: Data?
        var stamp: Date?
        var needsPush: Bool
        var pushedStamps: [Date] = []
    }

    private let state: Mutex<State>

    init(data: Data?, stamp: Date?, needsPush: Bool) {
        state = Mutex(State(data: data, stamp: stamp, needsPush: needsPush))
    }

    var data: Data? { state.withLock { $0.data } }
    var stamp: Date? { state.withLock { $0.stamp } }
    var needsPush: Bool { state.withLock { $0.needsPush } }
    var pushedStamps: [Date] { state.withLock { $0.pushedStamps } }

    func pending() -> RemoteTrainerState? {
        state.withLock { state in
            guard state.needsPush, let stamp = state.stamp else { return nil }
            return RemoteTrainerState(data: state.data, updatedAt: stamp)
        }
    }

    func updatedAt() -> Date? { stamp }

    func markPending() {
        state.withLock { state in
            if state.stamp != nil { state.needsPush = true }
        }
    }

    func markPushed(updatedAt: Date) {
        state.withLock { state in
            state.pushedStamps.append(updatedAt)
            if state.stamp == updatedAt { state.needsPush = false }
        }
    }

    func apply(_ remote: RemoteTrainerState) -> Bool {
        state.withLock { state in
            state.data = remote.data
            state.stamp = remote.updatedAt
            state.needsPush = false
            return true
        }
    }
}

private func run(_ store: FakeTrainerStore, _ responses: [ScriptedTransport.Response], defaults: String = migratedSuite()) async throws -> (RemoteSyncReport, ScriptedTransport) {
    let container = try TrainingSchema.container(inMemory: true)
    let transport = ScriptedTransport(responses)
    let client = RemoteClient(baseURL: URL(string: "https://sync.example.test")!, keys: keys, transport: transport)
    let engine = RemoteSyncEngine(container: container, client: client, keys: keys, defaultsSuite: defaults, trainerStore: store, now: { base.addingTimeInterval(3_600) })
    return (try await engine.sync(), transport)
}

private func remote(_ data: Data?, at stamp: Date, seq: Int64 = 3, sealed: Bool = false) throws -> ScriptedTransport.Response {
    let payload = try data.map { sealed ? try RemotePayload.seal(trainer: $0, key: keys.payload) : try RemotePayload.plain(trainer: $0) }
    let record = RemoteRecord(kind: .trainer, id: "plan", updatedAt: stamp, deleted: data == nil, payload: payload, seq: seq, format: sealed ? nil : .plain)
    let encoded = String(data: try RemoteJSON.encoder().encode([record]), encoding: .utf8)!
    return .json(200, #"{"records":\#(encoded),"cursor":\#(seq),"hasMore":false}"#)
}

@Suite struct RemoteSyncTrainerTests {
    @Test func pushesPendingPlanAsPlainWithFixedId() async throws {
        let store = FakeTrainerStore(data: plan, stamp: base, needsPush: true)

        let (report, transport) = try await run(store, [accepted(), emptyPage])

        let sent = try #require(transport.pushBodies.first?.first)
        #expect(sent["kind"] as? String == "trainer")
        #expect(sent["id"] as? String == "plan")
        #expect(sent["format"] as? String == "plain")
        #expect(Data((sent["payload"] as? String ?? "").utf8) == plan)
        #expect(report.pushed == 1)
        #expect(store.needsPush == false)
    }

    @Test func doesNotPushWhenNothingChanged() async throws {
        let store = FakeTrainerStore(data: plan, stamp: base, needsPush: false)

        let (_, transport) = try await run(store, [emptyPage])

        #expect(transport.pushBodies.isEmpty)
    }

    @Test func pushesLocalPlanCreatedBeforeSyncExisted() async throws {
        let store = FakeTrainerStore(data: plan, stamp: base.addingTimeInterval(-86_400 * 30), needsPush: true)

        let (report, transport) = try await run(store, [accepted(), emptyPage])

        #expect(transport.pushBodies.first?.first?["kind"] as? String == "trainer")
        #expect(report.pushed == 1)
        #expect(store.needsPush == false)
    }

    @Test func pushesDeletionAsTombstone() async throws {
        let store = FakeTrainerStore(data: nil, stamp: base, needsPush: true)

        let (_, transport) = try await run(store, [accepted(), emptyPage])

        let sent = try #require(transport.pushBodies.first?.first)
        #expect(sent["deleted"] as? Bool == true)
        #expect(sent["format"] as? String == "plain")
        #expect(sent["payload"] is NSNull)
        #expect(store.needsPush == false)
    }

    @Test func newerRemotePlanReplacesLocal() async throws {
        let store = FakeTrainerStore(data: plan, stamp: base, needsPush: false)
        let newer = Data(#"{"name":"do outro aparelho"}"#.utf8)

        let (report, _) = try await run(store, [try remote(newer, at: base.addingTimeInterval(60))])

        #expect(store.data == newer)
        #expect(store.stamp == base.addingTimeInterval(60))
        #expect(report.trainerChanged)
        #expect(report.applied == 1)
    }

    @Test func remotePlanSealedWithTheDeviceKeyIsStillRead() async throws {
        let store = FakeTrainerStore(data: nil, stamp: nil, needsPush: false)
        let legacy = Data(#"{"name":"selado pelo aparelho"}"#.utf8)

        let (report, _) = try await run(store, [try remote(legacy, at: base, sealed: true)])

        #expect(store.data == legacy)
        #expect(report.trainerChanged)
    }

    @Test func firstSyncAfterUpdateResendsTheUnchangedPlanAsPlainOnce() async throws {
        let store = FakeTrainerStore(data: plan, stamp: base, needsPush: false)
        let suite = migratedSuite()
        UserDefaults(suiteName: suite)?.removeObject(forKey: RemoteSyncConstants.trainerPlainMigrationKey)

        let (first, firstTransport) = try await run(store, [accepted(), emptyPage], defaults: suite)
        let (second, secondTransport) = try await run(store, [emptyPage], defaults: suite)

        let sent = try #require(firstTransport.pushBodies.first?.first)
        #expect(sent["kind"] as? String == "trainer")
        #expect(sent["format"] as? String == "plain")
        #expect(first.pushed == 1)
        #expect(second.pushed == 0)
        #expect(secondTransport.pushBodies.isEmpty)
    }

    @Test func olderRemotePlanKeepsLocal() async throws {
        let store = FakeTrainerStore(data: plan, stamp: base.addingTimeInterval(60), needsPush: false)

        let (report, _) = try await run(store, [try remote(Data(#"{"name":"velho"}"#.utf8), at: base)])

        #expect(store.data == plan)
        #expect(!report.trainerChanged)
    }

    @Test func localEditNewerThanServerWinsAndIsNotOverwrittenByPull() async throws {
        let store = FakeTrainerStore(data: plan, stamp: base.addingTimeInterval(120), needsPush: true)
        let older = Data(#"{"name":"servidor"}"#.utf8)

        let (report, _) = try await run(store, [accepted(), try remote(older, at: base.addingTimeInterval(60))])

        #expect(store.data == plan)
        #expect(store.needsPush == false)
        #expect(!report.trainerChanged)
    }

    @Test func simultaneousAdjustmentsKeepTheNewestAndReloadTheOther() async throws {
        let store = FakeTrainerStore(data: plan, stamp: base.addingTimeInterval(10), needsPush: true)
        let winner = Data(#"{"name":"ajuste do outro"}"#.utf8)

        let (report, _) = try await run(store, [accepted(ignored: #"[{"kind":"trainer","id":"plan"}]"#), try remote(winner, at: base.addingTimeInterval(20))])

        #expect(store.data == winner)
        #expect(store.needsPush == false)
        #expect(report.trainerChanged)
    }

    @Test func remoteTombstoneDeletesLocalPlan() async throws {
        let store = FakeTrainerStore(data: plan, stamp: base, needsPush: false)

        let (report, _) = try await run(store, [try remote(nil, at: base.addingTimeInterval(60))])

        #expect(store.data == nil)
        #expect(report.trainerChanged)
    }

    @Test func remoteTombstoneWithoutLocalPlanIsIgnored() async throws {
        let store = FakeTrainerStore(data: nil, stamp: nil, needsPush: false)

        let (report, _) = try await run(store, [try remote(nil, at: base)])

        #expect(!report.trainerChanged)
        #expect(store.stamp == nil)
    }

    @Test func tamperedPayloadFailsTheSync() async throws {
        let store = FakeTrainerStore(data: nil, stamp: nil, needsPush: false)
        let record = RemoteRecord(kind: .trainer, id: "plan", updatedAt: base, deleted: false, payload: "AAAA", seq: 3)
        let encoded = String(data: try RemoteJSON.encoder().encode([record]), encoding: .utf8)!

        await #expect(throws: RemoteSyncError.tamperedPayload) {
            _ = try await run(store, [.json(200, #"{"records":\#(encoded),"cursor":3,"hasMore":false}"#)])
        }
    }
}
