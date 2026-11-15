import Foundation
import GarminAPI
import Insights
import RemoteSync
import Storage
import SwiftData
import Synchronization
import Testing
import TrainingCore
@testable import trAIning

private final class FakeRecordsServer: HTTPTransport {
    private struct State {
        var records: [String: [String: Any]] = [:]
        var seq = 0
    }

    private let state = Mutex(State())

    var trainerRecord: [String: Any]? { state.withLock { $0.records["trainer/plan"] } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let body: Data = state.withLock { state in
            if request.httpMethod == "POST" {
                let incoming = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])?["records"] as? [[String: Any]] ?? []
                for record in incoming {
                    let key = "\(record["kind"] as? String ?? "")/\(record["id"] as? String ?? "")"
                    if let current = state.records[key], (current["updatedAt"] as? String ?? "") >= (record["updatedAt"] as? String ?? "") { continue }
                    state.seq += 1
                    state.records[key] = record.merging(["seq": state.seq]) { _, new in new }
                }
                return Data(#"{"cursor":\#(state.seq),"ignored":[]}"#.utf8)
            }
            let since = Int(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "since" }?.value ?? "0") ?? 0
            let page = state.records.values.filter { ($0["seq"] as? Int ?? 0) > since }.sorted { ($0["seq"] as? Int ?? 0) < ($1["seq"] as? Int ?? 0) }
            let encoded = (try? JSONSerialization.data(withJSONObject: ["records": page, "cursor": max(state.seq, since), "hasMore": false])) ?? Data()
            return encoded
        }
        return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor
@Suite struct TrainerSyncTests {
    private static let keys = try! RemoteKeys(syncKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8")
    private static let base = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Device {
        let store: TrainerStore
        let container: ModelContainer
        let engine: RemoteSyncEngine

        @discardableResult func sync() async throws -> RemoteSyncReport { try await engine.sync() }
    }

    private static func device(_ server: FakeRecordsServer, clock: Date) throws -> Device {
        let url = FileManager.default.temporaryDirectory.appending(path: "trainer-sync-\(UUID().uuidString).json")
        let defaults = UserDefaults(suiteName: "trainer-sync-\(UUID().uuidString)")!
        let store = TrainerStore(url: url, defaults: defaults, now: { clock })
        let container = try TrainingSchema.container(inMemory: true)
        let client = RemoteClient(baseURL: URL(string: "https://sync.example.test")!, keys: keys, transport: server)
        let engine = RemoteSyncEngine(container: container, client: client, keys: keys, defaultsSuite: "trainer-sync-\(UUID().uuidString)", trainerStore: store)
        return Device(store: store, container: container, engine: engine)
    }

    private static func edited(_ plan: TrainerPlan, summary: String) -> TrainerPlan {
        var next = plan
        next.versions.append(TrainerVersion(number: plan.versions.count + 1, createdAt: base, trigger: .created, summary: summary, changes: []))
        return next
    }

    @Test func sendsSavedPlanAsPlainToTheServer() async throws {
        let server = FakeRecordsServer()
        let a = try Self.device(server, clock: Self.base)

        try a.store.save(TrainerStoreTests.plan())
        let report = try await a.sync()

        let record = try #require(server.trainerRecord)
        #expect(record["deleted"] as? Bool == false)
        #expect(record["format"] as? String == "plain")
        #expect(record["payload"] is String)
        #expect(report.pushed == 1)
        #expect(a.store.pending() == nil)
    }

    @Test func otherDeviceReceivesThePlanAndKeepsItsOwnSeenVersion() async throws {
        let server = FakeRecordsServer()
        let a = try Self.device(server, clock: Self.base)
        let b = try Self.device(server, clock: Self.base)
        let plan = TrainerStoreTests.plan()
        b.store.markSeen(1)

        try a.store.save(plan)
        try await a.sync()
        let report = try await b.sync()

        #expect(b.store.load() == plan)
        #expect(report.trainerChanged)
        #expect(b.store.seenVersion == 1)
        #expect(b.store.strengthMigrated)
        #expect(b.store.pending() == nil)
    }

    @Test func newerPlanWinsAndTheOtherDeviceReloads() async throws {
        let server = FakeRecordsServer()
        let a = try Self.device(server, clock: Self.base)
        let b = try Self.device(server, clock: Self.base.addingTimeInterval(60))
        let plan = TrainerStoreTests.plan()
        try a.store.save(plan)
        try await a.sync()
        try await b.sync()

        let fromA = Self.edited(plan, summary: "ajuste no aparelho A")
        let fromB = Self.edited(plan, summary: "ajuste no aparelho B")
        try a.store.save(fromA)
        try b.store.save(fromB)
        try await a.sync()
        let afterB = try await b.sync()
        let afterA = try await a.sync()

        #expect(b.store.load() == fromB)
        #expect(!afterB.trainerChanged)
        #expect(a.store.load() == fromB)
        #expect(afterA.trainerChanged)
        #expect(a.store.load()?.versions.count == plan.versions.count + 1)
    }

    @Test func localEditNewerThanServerIsPushedAndKept() async throws {
        let server = FakeRecordsServer()
        let a = try Self.device(server, clock: Self.base)
        let b = try Self.device(server, clock: Self.base.addingTimeInterval(60))
        try a.store.save(TrainerStoreTests.plan())
        try await a.sync()
        let local = Self.edited(TrainerStoreTests.plan(), summary: "mais novo")
        try b.store.save(local)

        let report = try await b.sync()

        #expect(b.store.load() == local)
        #expect(!report.trainerChanged)
        #expect(server.trainerRecord?["updatedAt"] as? String == RemoteTimestamp.string(from: Self.base.addingTimeInterval(60)))
    }

    @Test func deletingThePlanDeletesItOnTheServerAndOnOtherDevices() async throws {
        let server = FakeRecordsServer()
        let a = try Self.device(server, clock: Self.base)
        let b = try Self.device(server, clock: Self.base.addingTimeInterval(60))
        try a.store.save(TrainerStoreTests.plan())
        try await a.sync()
        try await b.sync()

        try b.store.delete()
        try await b.sync()
        let report = try await a.sync()

        #expect(server.trainerRecord?["deleted"] as? Bool == true)
        #expect(a.store.load() == nil)
        #expect(report.trainerChanged)
        #expect(b.store.pending() == nil)
    }

    @Test func planCreatedBeforeSyncExistedIsPushedOnFirstSync() async throws {
        let server = FakeRecordsServer()
        let a = try Self.device(server, clock: Self.base)
        try TrainerStore(url: a.store.url, defaults: UserDefaults(suiteName: "trainer-legacy-\(UUID().uuidString)")!).save(TrainerStoreTests.plan())

        #expect(a.store.pending() != nil)
        let report = try await a.sync()

        #expect(report.pushed == 1)
        #expect(server.trainerRecord?["deleted"] as? Bool == false)
        #expect(a.store.pending() == nil)
    }

    @Test func modelReloadsPlanReplacedByTheOtherDeviceWithoutDuplicatingVersions() async throws {
        let server = FakeRecordsServer()
        let a = try Self.device(server, clock: Self.base)
        let b = try Self.device(server, clock: Self.base)
        let plan = TrainerStoreTests.plan()
        try a.store.save(plan)
        try await a.sync()
        try await b.sync()
        let model = TrainerModel(container: b.container, store: b.store, today: { Day(iso: "2027-06-01")! })
        #expect(model.plan == plan)

        let adjusted = Self.edited(plan, summary: "ajuste automático")
        try a.store.save(adjusted)
        try await a.sync()
        try await b.sync()
        model.reloadFromStore()

        #expect(model.plan == adjusted)
        #expect(model.plan?.versions.count == plan.versions.count + 1)
    }

    @Test func modelPersistingPlanNotifiesSync() throws {
        let store = TrainerStore(
            url: FileManager.default.temporaryDirectory.appending(path: "trainer-model-\(UUID().uuidString).json"),
            defaults: UserDefaults(suiteName: "trainer-model-\(UUID().uuidString)")!
        )
        try store.save(TrainerStoreTests.plan())
        let model = TrainerModel(container: try TrainingSchema.container(inMemory: true), store: store)
        var changes = 0
        model.onChange = { changes += 1 }

        model.deletePlan()

        #expect(changes == 1)
        #expect(store.load() == nil)
        #expect(store.pending()?.deleted == true)
    }
}
