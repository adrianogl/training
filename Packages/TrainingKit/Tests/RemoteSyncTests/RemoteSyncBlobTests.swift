import Foundation
import Storage
import Synchronization
import Testing
@testable import RemoteSync

private let keys = try! RemoteKeys(syncKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")
private let base = Date(timeIntervalSince1970: 1_800_000_000)
private let emptyPage = ScriptedTransport.Response.json(200, #"{"records":[],"cursor":1,"hasMore":false}"#)

private final class FakeBlobStore: RemoteBlobStore {
    let kind: RemoteRecordKind
    private let state: Mutex<(pending: [RemoteBlob], applied: [RemoteBlob], pushed: [RemoteBlob])>

    init(kind: RemoteRecordKind, pending: [RemoteBlob]) {
        self.kind = kind
        state = Mutex((pending, [], []))
    }

    var applied: [RemoteBlob] { state.withLock { $0.applied } }
    var pushed: [RemoteBlob] { state.withLock { $0.pushed } }

    func pendingBlobs() -> [RemoteBlob] { state.withLock { $0.pending } }
    func markBlobsPushed(_ blobs: [RemoteBlob]) { state.withLock { $0.pushed += blobs } }
    func apply(_ blob: RemoteBlob) -> Bool { state.withLock { $0.applied.append(blob) }; return true }
}

private func run(_ stores: [FakeBlobStore], _ responses: [ScriptedTransport.Response]) async throws -> (RemoteSyncReport, ScriptedTransport) {
    let container = try TrainingSchema.container(inMemory: true)
    let transport = ScriptedTransport(responses)
    let client = RemoteClient(baseURL: URL(string: "https://sync.example.test")!, keys: keys, transport: transport)
    let engine = RemoteSyncEngine(container: container, client: client, keys: keys, defaultsSuite: migratedSuite(), blobStores: stores, now: { base })
    return (try await engine.sync(), transport)
}

@Suite struct RemoteSyncBlobTests {
    @Test func accountWithoutKeyReadsPlainAndSkipsOldSealedRecords() async throws {
        let store = FakeBlobStore(kind: .preference, pending: [])
        let plain = RemoteRecord(kind: .preference, id: "weeklyGoalKm", updatedAt: base, deleted: false, payload: try RemotePayload.plain(blob: Data("50".utf8)), seq: 1, format: .plain)
        let sealed = RemoteRecord(kind: .preference, id: "shareTemplate", updatedAt: base, deleted: false, payload: try RemotePayload.seal(blob: Data("1".utf8), kind: .preference, id: "shareTemplate", key: keys.payload), seq: 2)
        let encoded = String(data: try RemoteJSON.encoder().encode([plain, sealed]), encoding: .utf8)!
        let container = try TrainingSchema.container(inMemory: true)
        let transport = ScriptedTransport([.json(200, #"{"records":\#(encoded),"cursor":2,"hasMore":false}"#)])
        let client = RemoteClient(baseURL: URL(string: "https://sync.example.test")!, bearer: "sessao", transport: transport)
        let engine = RemoteSyncEngine(container: container, client: client, defaultsSuite: migratedSuite(), blobStores: [store], now: { base })

        _ = try await engine.sync()

        #expect(store.applied.map(\.id) == ["weeklyGoalKm"])
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer sessao")
    }

    @Test func pushesPendingBlobsSealedWithTheirKind() async throws {
        let blob = RemoteBlob(id: "weeklyGoalKm", data: Data("50".utf8), updatedAt: base)
        let store = FakeBlobStore(kind: .preference, pending: [blob])

        let (_, transport) = try await run([store], [.json(200, #"{"cursor":1,"ignored":[]}"#), emptyPage])

        let sent = try #require(transport.pushBodies.first?.first)
        #expect(sent["kind"] as? String == "preference")
        #expect(sent["format"] as? String == "plain")
        #expect(try RemotePayload.decodeBlob(sent["payload"] as? String ?? "") == Data("50".utf8))
        #expect(store.pushed == [blob])
    }

    @Test func remoteBlobGoesToTheStoreOfItsKind() async throws {
        let preferences = FakeBlobStore(kind: .preference, pending: [])
        let chats = FakeBlobStore(kind: .chat, pending: [])
        let payload = try RemotePayload.seal(blob: Data("[]".utf8), kind: .chat, id: "trainer", key: keys.payload)
        let record = RemoteRecord(kind: .chat, id: "trainer", updatedAt: base, deleted: false, payload: payload, seq: 2)
        let encoded = String(data: try RemoteJSON.encoder().encode([record]), encoding: .utf8)!

        let (report, _) = try await run([preferences, chats], [.json(200, #"{"records":\#(encoded),"cursor":2,"hasMore":false}"#)])

        #expect(chats.applied.map(\.id) == ["trainer"])
        #expect(preferences.applied.isEmpty)
        #expect(report.changedKinds == [.chat])
    }
}
