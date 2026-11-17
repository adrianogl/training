import Foundation
import Storage
import Synchronization
import Testing
@testable import RemoteSync

private let keys = try! RemoteKeys(syncKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")
private let base = Date(timeIntervalSince1970: 1_800_000_000)
private let id = String(repeating: "a", count: 64)
private let emptyPage = ScriptedTransport.Response.json(200, #"{"records":[],"cursor":1,"hasMore":false}"#)

private final class FakeNarrativeStore: RemoteNarrativeStore {
    private struct State {
        var items: [String: RemoteNarrative]
        var pending: Set<String>
    }

    private let state: Mutex<State>

    init(_ items: [RemoteNarrative], pending: Set<String>) {
        state = Mutex(State(items: Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) }), pending: pending))
    }

    var pending: Set<String> { state.withLock { $0.pending } }
    func text(_ id: String) -> String? { state.withLock { $0.items[id]?.text } }

    func pendingNarratives() -> [RemoteNarrative] {
        state.withLock { state in state.pending.compactMap { state.items[$0] } }
    }

    func narrativeUpdatedAt(id: String) -> Date? {
        state.withLock { $0.items[id]?.updatedAt }
    }

    func markNarrativesPushed(_ narratives: [RemoteNarrative]) {
        state.withLock { state in
            for narrative in narratives where state.items[narrative.id] == narrative { state.pending.remove(narrative.id) }
        }
    }

    func apply(_ narrative: RemoteNarrative) -> Bool {
        state.withLock { state in
            state.items[narrative.id] = narrative
            state.pending.remove(narrative.id)
            return true
        }
    }
}

private func run(_ store: FakeNarrativeStore, _ responses: [ScriptedTransport.Response]) async throws -> (RemoteSyncReport, ScriptedTransport) {
    let container = try TrainingSchema.container(inMemory: true)
    let transport = ScriptedTransport(responses)
    let client = RemoteClient(baseURL: URL(string: "https://sync.example.test")!, keys: keys, transport: transport)
    let engine = RemoteSyncEngine(container: container, client: client, keys: keys, defaultsSuite: migratedSuite(), narrativeStore: store, now: { base.addingTimeInterval(3_600) })
    return (try await engine.sync(), transport)
}

private func remote(_ text: String, at stamp: Date) throws -> ScriptedTransport.Response {
    let record = RemoteRecord(kind: .narrative, id: id, updatedAt: stamp, deleted: false, payload: try RemotePayload.seal(narrative: text, id: id, key: keys.payload), seq: 3)
    let encoded = String(data: try RemoteJSON.encoder().encode([record]), encoding: .utf8)!
    return .json(200, #"{"records":\#(encoded),"cursor":3,"hasMore":false}"#)
}

@Suite struct RemoteSyncNarrativeTests {
    @Test func pushesPendingTextSealedByTheFactsHash() async throws {
        let store = FakeNarrativeStore([RemoteNarrative(id: id, text: "Treino bom a 4:53/km.", updatedAt: base)], pending: [id])

        let (report, transport) = try await run(store, [.json(200, #"{"cursor":1,"ignored":[]}"#), emptyPage])

        let sent = try #require(transport.pushBodies.first?.first)
        #expect(sent["kind"] as? String == "narrative")
        #expect(sent["id"] as? String == id)
        #expect(sent["format"] == nil)
        #expect(try RemotePayload.openNarrative(sent["payload"] as? String ?? "", id: id, key: keys.payload) == "Treino bom a 4:53/km.")
        #expect(report.pushed == 1)
        #expect(store.pending.isEmpty)
    }

    @Test func textFromAnotherDeviceIsSavedWhenMissing() async throws {
        let store = FakeNarrativeStore([], pending: [])

        let (report, transport) = try await run(store, [try remote("Do iPad.", at: base)])

        #expect(transport.pushBodies.isEmpty)
        #expect(store.text(id) == "Do iPad.")
        #expect(report.narrativesChanged)
    }

    @Test func newerTextWinsAndOlderIsKept() async throws {
        let localOlder = FakeNarrativeStore([RemoteNarrative(id: id, text: "Local.", updatedAt: base)], pending: [])
        let localNewer = FakeNarrativeStore([RemoteNarrative(id: id, text: "Local.", updatedAt: base.addingTimeInterval(120))], pending: [])

        _ = try await run(localOlder, [try remote("Remoto.", at: base.addingTimeInterval(60))])
        _ = try await run(localNewer, [try remote("Remoto.", at: base.addingTimeInterval(60))])

        #expect(localOlder.text(id) == "Remoto.")
        #expect(localNewer.text(id) == "Local.")
    }
}
