import Foundation
import RemoteSync
import Storage
import SwiftData
import Testing
@testable import trAIning

@MainActor
@Suite struct RemoteSyncModelTests {
    private typealias C = RemoteSyncSettingsConstants
    private static let validKey = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"

    private struct Harness {
        let container: ModelContainer
        let keyStore: MemoryKeyStore
        let server: FakeSyncServer
        let model: RemoteSyncModel
    }

    private static func harness(
        key: String? = nil,
        server: FakeSyncServer = FakeSyncServer(),
        auth: DeviceOwnerResult = .granted,
        clipboard: FakeClipboard = FakeClipboard(),
        setup: (ModelContext) -> Void = { _ in }
    ) throws -> Harness {
        let container = try TrainingSchema.container(inMemory: true)
        setup(container.mainContext)
        try container.mainContext.save()
        let keyStore = MemoryKeyStore(key)
        let model = RemoteSyncModel(
            container: container,
            keyStore: keyStore,
            transport: server,
            baseURL: URL(string: "https://sync.example.test")!,
            debounce: .milliseconds(50),
            authenticator: FakeAuthenticator(result: auth),
            clipboard: clipboard
        )
        return Harness(container: container, keyStore: keyStore, server: server, model: model)
    }

    @Test func offMakesNoCalls() async throws {
        let h = try Self.harness()

        h.model.scheduleSync()
        await h.model.waitForScheduledSync()
        await h.model.syncNow()

        #expect(h.server.requests.isEmpty)
        #expect(h.model.status == .off)
        #expect(h.model.chip == nil)
    }

    @Test func signedInAccountSyncsWithoutKey() async throws {
        let h = try Self.harness()
        #expect(h.model.status == .off)

        h.model.accountToken = { "sessao-da-conta" }
        await h.model.syncNow()

        #expect(h.model.isEnabled)
        #expect(h.server.requests == ["GET /api/v1/changes"])
        #expect(h.model.status == .idle)
    }

    @Test func debounceRunsASingleSync() async throws {
        let h = try Self.harness(key: Self.validKey)

        h.model.scheduleSync()
        h.model.scheduleSync()
        h.model.scheduleSync()
        await h.model.waitForScheduledSync()

        #expect(h.server.requests == ["GET /api/v1/changes"])
    }

    @Test func neverRunsTwoSyncsAtOnce() async throws {
        let h = try Self.harness(key: Self.validKey, server: FakeSyncServer(delay: .milliseconds(80)))

        let first = Task { await h.model.syncNow() }
        while h.model.status != .syncing { await Task.yield() }
        await h.model.syncNow()
        await first.value

        #expect(h.server.maxInFlight == 1)
        #expect(h.server.requests.count == 2)
    }

    @Test func offlineShowsPendingChangesChip() async throws {
        let h = try Self.harness(key: Self.validKey, server: FakeSyncServer(["POST /api/v1/changes": [.offline]])) { context in
            context.insert(RaceRecord(name: "Nova", day: "2026-12-01", distance: 10_000))
            context.insert(RaceDecisionRecord(activityId: 1, decision: .race))
        }

        await h.model.syncNow()

        #expect(h.model.status == .waitingForNetwork(pending: 2))
        #expect(h.model.chip == .waiting(C.waiting(2)))
    }

    @Test func refusedSessionShowsRefusedChip() async throws {
        let h = try Self.harness(key: Self.validKey, server: FakeSyncServer(["GET /api/v1/changes": [.status(401, "{}")]]))

        await h.model.syncNow()

        #expect(h.model.status == .failed(.keyNotFound))
        #expect(h.model.chip == .failed("Sync recusado: entre na conta de novo"))
    }

    @Test func quotaExceededShowsClearChip() async throws {
        let h = try Self.harness(key: Self.validKey, server: FakeSyncServer(["POST /api/v1/changes": [.status(413, #"{"error":"quota_exceeded"}"#)]])) { context in
            context.insert(RaceRecord(name: "Nova", day: "2026-12-01", distance: 10_000))
        }

        await h.model.syncNow()

        #expect(h.model.status == .failed(.quotaExceeded))
        #expect(h.model.chip == .failed(C.problemQuota))
    }

    @Test func systemClipboardKeepsTokenLocalAndExpires() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let options = SystemKeyClipboard.options(now: now)

        #expect(options[.localOnly] as? Bool == true)
        #expect(options[.expirationDate] as? Date == now.addingTimeInterval(C.clipboardLifetime))
        #expect(C.clipboardLifetime == 120)
    }

    @Test func baseURLUsesEnvironmentOnlyInDebug() {
        #expect(RemoteSyncModel.baseURL(environment: [:]) == AppConstants.remoteSyncBaseURL)
        #if DEBUG
        #expect(RemoteSyncModel.baseURL(environment: [AppConstants.remoteSyncURLEnvironmentVariable: "http://localhost:3000"]) == URL(string: "http://localhost:3000"))
        #endif
    }
}

private struct NoGarminKey: APIKeyStore {
    func read() throws -> String? { nil }
    func save(_ key: String) throws {}
    func delete() throws {}
}

@MainActor
@Suite struct AppModelRemoteSyncTests {
    private static func app(remoteKey: String?, server: FakeSyncServer) throws -> AppModel {
        let root = FileManager.default.temporaryDirectory.appending(path: "AppModelRemoteSync-\(UUID().uuidString)", directoryHint: .isDirectory)
        let scope = AccountScope(
            id: root.lastPathComponent, supportRoot: root.appending(path: "Support"), cachesRoot: root.appending(path: "Caches"),
            keychain: { _ in MemoryKeyStore() }
        )
        return AppModel(
            container: try TrainingSchema.container(inMemory: true),
            scope: scope,
            keyStore: NoGarminKey(),
            transport: server,
            remoteKeyStore: MemoryKeyStore(remoteKey),
            watchTokenStore: MemoryKeyStore(),
            remoteDefaults: scope.defaults,
            remoteBaseURL: URL(string: "https://sync.example.test")!,
            autoSyncEnabled: false
        )
    }

    @Test func garminSyncEndsWithRemoteSyncWhenEnabled() async throws {
        let server = FakeSyncServer()
        let app = try Self.app(remoteKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8", server: server)

        await app.syncNow(.launch)

        #expect(server.requests == ["GET /api/v1/changes"])
    }

    @Test func remoteSyncOffMakesNoCallAfterGarminSync() async throws {
        let server = FakeSyncServer()
        let app = try Self.app(remoteKey: nil, server: server)

        await app.syncNow(.launch)

        #expect(server.requests.isEmpty)
    }
}
