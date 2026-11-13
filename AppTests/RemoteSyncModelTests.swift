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

    @Test func activateCreatesAccountSavesKeyAndSyncs() async throws {
        let h = try Self.harness()

        await h.model.activate()

        let key = try #require(try h.keyStore.read())
        #expect(key.count == C.keyLength)
        #expect(h.server.requests == ["POST /api/v1/account", "GET /api/v1/changes"])
        #expect(h.model.status == .idle)
        #expect(h.model.lastSync != nil)
        #expect(h.model.chip == nil)
    }

    @Test func activateOfflineKeepsSyncOff() async throws {
        let h = try Self.harness(server: FakeSyncServer(["POST /api/v1/account": [.offline]]))

        await h.model.activate()

        #expect(try h.keyStore.read() == nil)
        #expect(h.model.status == .off)
        #expect(h.model.actionMessage == C.activateFailed)
    }

    @Test func pastedKeyFormatErrorsAreSpecific() {
        #expect(RemoteSyncModel.check("") == C.keyEmpty)
        #expect(RemoteSyncModel.check("q3Jx-7cVmN0pR2tYb8LkW4sZ1aHf") == C.keyLength(28))
        #expect(RemoteSyncModel.check(String(Self.validKey.dropLast()) + "!") == C.keyCharacters)
        #expect(RemoteSyncModel.check(String(Self.validKey.dropLast()) + "f") == C.keyMalformed)
        #expect(RemoteSyncModel.check("  \(Self.validKey)\n") == nil)
    }

    @Test func invalidPasteMakesNoCall() async throws {
        let h = try Self.harness()

        let connected = await h.model.connect("abc")

        #expect(!connected)
        #expect(h.model.pasteError == C.keyLength(3))
        #expect(h.server.requests.isEmpty)
        #expect(try h.keyStore.read() == nil)
    }

    @Test func pastedKeyUnknownOnServerIsNotSaved() async throws {
        let h = try Self.harness(server: FakeSyncServer(["GET /api/v1/changes": [.status(401, #"{"error":"x"}"#)]]))

        let connected = await h.model.connect(Self.validKey)

        #expect(!connected)
        #expect(h.model.pasteError == C.keyNotFoundOnServer)
        #expect(try h.keyStore.read() == nil)
        #expect(h.model.status == .off)
    }

    @Test func pastedKeyMergesLocalRaces() async throws {
        let h = try Self.harness { context in
            context.insert(RaceRecord(name: "Local", day: "2026-12-01", distance: 10_000))
            context.insert(RaceRecord(name: "Apagada", day: "2026-12-02", distance: 5_000, deletedAt: .now))
        }
        #expect(h.model.localCounts().races == 1)

        let connected = await h.model.connect(Self.validKey)

        #expect(connected)
        #expect(try h.keyStore.read() == Self.validKey)
        #expect(h.server.requests == ["POST /api/v1/changes", "GET /api/v1/changes"])
        #expect(h.model.status == .idle)
        #expect(try h.container.mainContext.fetch(FetchDescriptor<RaceRecord>()).map(\.name) == ["Local"])
    }

    @Test func disableKeepsLocalDataAndResetsCursor() async throws {
        let h = try Self.harness(key: Self.validKey) { context in
            context.insert(SyncState(remoteCursor: 9, remoteLastPush: .now))
            context.insert(RaceRecord(name: "Fica", day: "2026-12-01", distance: 10_000))
        }

        await h.model.disable()

        #expect(try h.keyStore.read() == nil)
        let state = try #require(try h.container.mainContext.fetch(FetchDescriptor<SyncState>()).first)
        #expect(state.remoteCursor == 0)
        #expect(state.remoteLastPush == nil)
        #expect(try h.container.mainContext.fetch(FetchDescriptor<RaceRecord>()).count == 1)
        #expect(h.model.status == .off)
        #expect(h.server.requests.isEmpty)
    }

    @Test func deleteServerDataDeletesAccountThenDisables() async throws {
        let h = try Self.harness(key: Self.validKey)

        let deleted = await h.model.deleteServerData()

        #expect(deleted)
        #expect(h.server.requests == ["DELETE /api/v1/account"])
        #expect(try h.keyStore.read() == nil)
        #expect(h.model.status == .off)
    }

    @Test func deleteServerDataOfflineKeepsSyncOn() async throws {
        let h = try Self.harness(key: Self.validKey, server: FakeSyncServer(["DELETE /api/v1/account": [.offline]]))

        let deleted = await h.model.deleteServerData()

        #expect(!deleted)
        #expect(try h.keyStore.read() == Self.validKey)
        #expect(h.model.actionMessage == C.deleteServerFailed)
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

    @Test func unknownKeyShowsRefusedChip() async throws {
        let h = try Self.harness(key: Self.validKey, server: FakeSyncServer(["GET /api/v1/changes": [.status(401, "{}")]]))

        await h.model.syncNow()

        #expect(h.model.status == .failed(.keyNotFound))
        #expect(h.model.chip == .failed("Sync recusado: chave não encontrada"))
    }

    @Test func quotaExceededShowsClearChip() async throws {
        let h = try Self.harness(key: Self.validKey, server: FakeSyncServer(["POST /api/v1/changes": [.status(413, #"{"error":"quota_exceeded"}"#)]])) { context in
            context.insert(RaceRecord(name: "Nova", day: "2026-12-01", distance: 10_000))
        }

        await h.model.syncNow()

        #expect(h.model.status == .failed(.quotaExceeded))
        #expect(h.model.chip == .failed(C.problemQuota))
    }

    @Test func activateAtAccountLimitExplainsIt() async throws {
        let h = try Self.harness(server: FakeSyncServer(["POST /api/v1/account": [.status(429, #"{"error":"rate_limited"}"#)]]))

        await h.model.activate()

        #expect(h.model.status == .off)
        #expect(h.model.actionMessage == C.accountLimit)
        #expect(try h.keyStore.read() == nil)
    }

    @Test func revealKeyNeedsDeviceOwner() async throws {
        let allowed = try Self.harness(key: Self.validKey)
        let denied = try Self.harness(key: Self.validKey, auth: .denied)

        #expect(await allowed.model.revealKey(reason: C.revealReason) == Self.validKey)
        #expect(await denied.model.revealKey(reason: C.revealReason) == nil)
        #expect(denied.model.keyMessage == nil)
    }

    @Test func deviceWithoutPasscodeExplainsWhyKeyIsHidden() async throws {
        let clipboard = FakeClipboard()
        let h = try Self.harness(key: Self.validKey, auth: .unavailable, clipboard: clipboard)

        #expect(await h.model.revealKey(reason: C.revealReason) == nil)
        #expect(h.model.keyMessage == C.noPasscode)
        #expect(await h.model.copyKey() == false)
        #expect(clipboard.values.isEmpty)
    }

    @Test func copyKeyGoesToClipboardAfterAuthentication() async throws {
        let clipboard = FakeClipboard()
        let h = try Self.harness(key: Self.validKey, clipboard: clipboard)

        #expect(await h.model.copyKey())
        #expect(clipboard.values == [Self.validKey])
        #expect(h.model.keyMessage == C.keyCopied)
    }

    @Test func systemClipboardKeepsKeyLocalAndExpires() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let options = SystemKeyClipboard.options(now: now)

        #expect(options[.localOnly] as? Bool == true)
        #expect(options[.expirationDate] as? Date == now.addingTimeInterval(C.clipboardLifetime))
        #expect(C.clipboardLifetime == 120)
        #expect(C.keyCopied.contains("2 minutos"))
        #expect(C.keyCopied.contains("AirDrop"))
    }

    @Test func disableDuringSlowSyncEndsOffAndClean() async throws {
        let h = try Self.harness(key: Self.validKey, server: FakeSyncServer(delay: .milliseconds(150))) { context in
            context.insert(RaceRecord(name: "Pendente", day: "2026-12-01", distance: 10_000))
        }
        let running = Task { await h.model.syncNow() }
        while h.model.status != .syncing { await Task.yield() }

        await h.model.disable()
        await running.value

        let state = try #require(try h.container.mainContext.fetch(FetchDescriptor<SyncState>()).first)
        #expect(state.remoteLastPush == nil)
        #expect(state.remoteCursor == 0)
        #expect(h.model.status == .off)
        #expect(try h.keyStore.read() == nil)
    }

    @Test func reactivatingWithNewAccountPushesEveryRace() async throws {
        let server = FakeSyncServer(delay: .milliseconds(50))
        let race = RaceRecord(name: "Pendente", day: "2026-12-01", distance: 10_000)
        let h = try Self.harness(key: Self.validKey, server: server) { context in context.insert(race) }
        let running = Task { await h.model.syncNow() }
        while h.model.status != .syncing { await Task.yield() }
        await h.model.disable()
        await running.value

        await h.model.activate()

        #expect(h.model.status == .idle)
        #expect(server.pushedIds.filter { $0 == race.id.uuidString }.count == 2)
    }

    @Test func deleteServerDataWaitsForRunningSync() async throws {
        let server = FakeSyncServer(delay: .milliseconds(100))
        let h = try Self.harness(key: Self.validKey, server: server)
        let running = Task { await h.model.syncNow() }
        while h.model.status != .syncing { await Task.yield() }

        #expect(await h.model.deleteServerData())
        await running.value

        #expect(server.requests == ["GET /api/v1/changes", "DELETE /api/v1/account"])
        #expect(server.maxInFlight == 1)
        #expect(h.model.status == .off)
    }

    @Test func countsIgnoreTombstones() async throws {
        let h = try Self.harness(key: Self.validKey) { context in
            context.insert(RaceRecord(name: "A", day: "2026-12-01", distance: 10_000))
            context.insert(RaceRecord(name: "B", day: "2026-12-01", distance: 10_000, deletedAt: .now))
            context.insert(RaceDecisionRecord(activityId: 1, decision: .race))
            context.insert(RaceDecisionRecord(activityId: 2, decision: .notRace, deletedAt: .now))
        }

        #expect(h.model.localCounts() == RemoteSyncCounts(races: 1, decisions: 1))
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
        AppModel(
            container: try TrainingSchema.container(inMemory: true),
            keyStore: NoGarminKey(),
            transport: server,
            remoteKeyStore: MemoryKeyStore(remoteKey),
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
