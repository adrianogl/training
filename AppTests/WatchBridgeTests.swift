import Foundation
import Insights
import Metrics
import RemoteSync
import Storage
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct WatchBridgeTests {
    private typealias C = RemoteSyncSettingsConstants
    private static let syncKey = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8"
    private static let readiness = WatchReadiness(day: "2026-11-12", score: 63, verdict: "Treino moderado")

    private struct Harness {
        let keyStore: MemoryKeyStore
        let watchStore: MemoryKeyStore
        let server: FakeSyncServer
        let clipboard: FakeClipboard
        let model: RemoteSyncModel
    }

    private static func harness(
        key: String? = syncKey,
        watchToken: String? = nil,
        server: FakeSyncServer = FakeSyncServer(),
        auth: DeviceOwnerResult = .granted
    ) throws -> Harness {
        let keyStore = MemoryKeyStore(key)
        let watchStore = MemoryKeyStore(watchToken)
        let clipboard = FakeClipboard()
        let model = RemoteSyncModel(
            container: try TrainingSchema.container(inMemory: true),
            keyStore: keyStore,
            transport: server,
            baseURL: URL(string: "https://sync.example.test")!,
            debounce: .milliseconds(50),
            authenticator: FakeAuthenticator(result: auth),
            clipboard: clipboard,
            watchTokenStore: watchStore,
            defaults: UserDefaults(suiteName: "WatchBridgeTests.\(UUID().uuidString)")!
        )
        return Harness(keyStore: keyStore, watchStore: watchStore, server: server, clipboard: clipboard, model: model)
    }

    @Test func generateSendsOnlyTheHashAndKeepsTokenLocally() async throws {
        let h = try Self.harness()

        await h.model.generateWatchToken()

        let token = try #require(try h.watchStore.read())
        let hash = try #require(WatchToken.hash(token))
        #expect(h.server.requests == ["PUT /api/v1/watch/token"])
        #expect(h.server.bodies("PUT /api/v1/watch/token") == [#"{"tokenHash":"\#(hash)"}"#])
        #expect(!h.server.bodies("PUT /api/v1/watch/token").joined().contains(token))
        #expect(h.model.hasWatchToken)
        #expect(h.model.watchMessage == C.watchInstructions)
    }

    @Test func generateFailureKeepsNoToken() async throws {
        let h = try Self.harness(server: FakeSyncServer(["PUT /api/v1/watch/token": [.offline]]))

        await h.model.generateWatchToken()

        #expect(try h.watchStore.read() == nil)
        #expect(!h.model.hasWatchToken)
        #expect(h.model.watchError == C.watchGenerateFailed)
    }

    @Test func tokenConflictRetriesOnceWithNewToken() async throws {
        let server = FakeSyncServer(["PUT /api/v1/watch/token": [.status(409, #"{"error":"token_conflict"}"#), .status(204, "")]])
        let h = try Self.harness(server: server)

        await h.model.generateWatchToken()

        let token = try #require(try h.watchStore.read())
        let bodies = server.bodies("PUT /api/v1/watch/token")
        #expect(bodies.count == 2)
        #expect(bodies[0] != bodies[1])
        #expect(bodies[1] == #"{"tokenHash":"\#(WatchToken.hash(token)!)"}"#)
        #expect(h.model.hasWatchToken)
    }

    @Test func repeatedTokenConflictGivesUp() async throws {
        let server = FakeSyncServer(["PUT /api/v1/watch/token": [.status(409, #"{"error":"token_conflict"}"#)]])
        let h = try Self.harness(server: server)

        await h.model.generateWatchToken()

        #expect(server.requests.count == 2)
        #expect(try h.watchStore.read() == nil)
        #expect(h.model.watchError == C.watchGenerateFailed)
    }

    @Test func generateAgainReplacesToken() async throws {
        let h = try Self.harness(watchToken: WatchToken.generate())
        let previous = try #require(try h.watchStore.read())

        await h.model.generateWatchToken()

        let current = try #require(try h.watchStore.read())
        #expect(current != previous)
        #expect(h.server.bodies("PUT /api/v1/watch/token") == [#"{"tokenHash":"\#(WatchToken.hash(current)!)"}"#])
    }

    @Test func revokeDeletesOnServerAndLocally() async throws {
        let h = try Self.harness(watchToken: WatchToken.generate())

        await h.model.revokeWatchToken()

        #expect(h.server.requests == ["DELETE /api/v1/watch/token"])
        #expect(try h.watchStore.read() == nil)
        #expect(!h.model.hasWatchToken)
    }

    @Test func revokeFailureKeepsToken() async throws {
        let token = WatchToken.generate()
        let h = try Self.harness(watchToken: token, server: FakeSyncServer(["DELETE /api/v1/watch/token": [.offline]]))

        await h.model.revokeWatchToken()

        #expect(try h.watchStore.read() == token)
        #expect(h.model.hasWatchToken)
        #expect(h.model.watchError == C.watchRevokeFailed)
    }

    @Test func copyTokenNeedsDeviceOwner() async throws {
        let token = WatchToken.generate()
        let granted = try Self.harness(watchToken: token)
        let denied = try Self.harness(watchToken: token, auth: .denied)

        #expect(await granted.model.copyWatchToken())
        #expect(!(await denied.model.copyWatchToken()))

        #expect(granted.clipboard.values == [token])
        #expect(granted.model.watchMessage == C.watchTokenCopied)
        #expect(denied.clipboard.values.isEmpty)
    }

    @Test func disablingSyncDeletesWatchToken() async throws {
        let h = try Self.harness(watchToken: WatchToken.generate())

        await h.model.disable()

        #expect(try h.watchStore.read() == nil)
        #expect(!h.model.hasWatchToken)
    }

    @Test func deletingServerDataDeletesWatchToken() async throws {
        let h = try Self.harness(watchToken: WatchToken.generate())

        #expect(await h.model.deleteServerData())

        #expect(try h.watchStore.read() == nil)
        #expect(h.server.requests == ["DELETE /api/v1/account"])
    }

    @Test func disablingSyncRevokesWatchTokenOnServer() async throws {
        let h = try Self.harness(watchToken: WatchToken.generate())

        await h.model.disable()

        #expect(h.server.requests == ["DELETE /api/v1/watch/token"])
        #expect(try h.keyStore.read() == nil)
    }

    @Test func disablingOfflineStillTurnsSyncOff() async throws {
        let server = FakeSyncServer(["DELETE /api/v1/watch/token": [.offline]])
        let h = try Self.harness(watchToken: WatchToken.generate(), server: server)

        await h.model.disable()

        #expect(server.requests == ["DELETE /api/v1/watch/token"])
        #expect(try h.keyStore.read() == nil)
        #expect(try h.watchStore.read() == nil)
        #expect(h.model.status == .off)
    }

    @Test func disablingWithoutWatchTokenMakesNoCall() async throws {
        let h = try Self.harness()

        await h.model.disable()

        #expect(h.server.requests.isEmpty)
    }

    @Test func generatingPublishesAvailableReadinessRightAway() async throws {
        let h = try Self.harness()
        h.model.readinessProvider = { Self.readiness }

        await h.model.generateWatchToken()

        #expect(h.server.requests == ["PUT /api/v1/watch/token", "PUT /api/v1/watch/readiness"])
        #expect(h.server.bodies("PUT /api/v1/watch/readiness") == [#"{"day":"2026-11-12","score":63,"verdict":"Treino moderado"}"#])
    }

    @Test func publishSendsReadinessOnceForSameValues() async throws {
        let h = try Self.harness(watchToken: WatchToken.generate())

        await h.model.publishReadiness(Self.readiness)
        await h.model.publishReadiness(Self.readiness)
        await h.model.publishReadiness(WatchReadiness(day: "2026-11-12", score: 70, verdict: "Treino moderado"))

        #expect(h.server.bodies("PUT /api/v1/watch/readiness") == [
            #"{"day":"2026-11-12","score":63,"verdict":"Treino moderado"}"#,
            #"{"day":"2026-11-12","score":70,"verdict":"Treino moderado"}"#,
        ])
    }

    @Test func publishWithoutWatchTokenOrSyncMakesNoCall() async throws {
        let noToken = try Self.harness()
        let noSync = try Self.harness(key: nil, watchToken: WatchToken.generate())

        await noToken.model.publishReadiness(Self.readiness)
        await noSync.model.publishReadiness(Self.readiness)

        #expect(noToken.server.requests.isEmpty)
        #expect(noSync.server.requests.isEmpty)
    }

    @Test func failedPublishRetriesNextTime() async throws {
        let server = FakeSyncServer(["PUT /api/v1/watch/readiness": [.offline, .status(204, "")]])
        let h = try Self.harness(watchToken: WatchToken.generate(), server: server)

        await h.model.publishReadiness(Self.readiness)
        await h.model.publishReadiness(Self.readiness)
        await h.model.publishReadiness(Self.readiness)

        #expect(server.requests == ["PUT /api/v1/watch/readiness", "PUT /api/v1/watch/readiness"])
    }

    @Test func newTokenResendsSameReadiness() async throws {
        let h = try Self.harness(watchToken: WatchToken.generate())

        await h.model.publishReadiness(Self.readiness)
        await h.model.generateWatchToken()
        await h.model.publishReadiness(Self.readiness)

        #expect(h.server.bodies("PUT /api/v1/watch/readiness").count == 2)
    }
}

@MainActor
@Suite struct AppModelWatchReadinessTests {
    private static let day = Day(year: 2026, month: 11, day: 12)

    private static func summary(score: Int?, verdict: ReadinessVerdict?) -> TodaySummary {
        var summary = TodaySummary.empty
        summary.readiness = score.map { ReadinessBreakdown(score: $0, normal: nil, factors: []) }
        summary.verdict = verdict
        return summary
    }

    private static func app(remoteKey: String?, watchToken: String?, server: FakeSyncServer, today: Day = day) throws -> AppModel {
        AppModel(
            container: try TrainingSchema.container(inMemory: true),
            keyStore: MemoryKeyStore(),
            transport: server,
            remoteKeyStore: MemoryKeyStore(remoteKey),
            watchTokenStore: MemoryKeyStore(watchToken),
            remoteDefaults: UserDefaults(suiteName: "AppModelWatchReadinessTests.\(UUID().uuidString)")!,
            remoteBaseURL: URL(string: "https://sync.example.test")!,
            autoSyncEnabled: false,
            today: { today }
        )
    }

    @Test func generatingTokenSendsTodaysReadinessFromLastSync() async throws {
        let server = FakeSyncServer()
        let app = try Self.app(remoteKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8", watchToken: nil, server: server)
        await app.publishWatchReadiness(summary: Self.summary(score: 81, verdict: .hard), day: Self.day)
        #expect(server.requests.isEmpty)

        await app.remoteSync.generateWatchToken()

        #expect(server.requests == ["PUT /api/v1/watch/token", "PUT /api/v1/watch/readiness"])
        #expect(server.bodies("PUT /api/v1/watch/readiness") == [#"{"day":"2026-11-12","score":81,"verdict":"Pode treinar forte"}"#])
    }

    @Test func generatingTokenSkipsYesterdaysReadiness() async throws {
        let server = FakeSyncServer()
        let app = try Self.app(
            remoteKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8", watchToken: nil, server: server,
            today: Day(year: 2026, month: 11, day: 13)
        )
        await app.publishWatchReadiness(summary: Self.summary(score: 81, verdict: .hard), day: Self.day)

        await app.remoteSync.generateWatchToken()

        #expect(server.requests == ["PUT /api/v1/watch/token"])
    }

    @Test func readinessUsesTodayScoreAndShortVerdict() {
        let readiness = AppModel.watchReadiness(summary: Self.summary(score: 63, verdict: .moderate), day: Self.day)

        #expect(readiness == WatchReadiness(day: "2026-11-12", score: 63, verdict: TodayConstants.verdictPhrases[.moderate]!))
    }

    @Test func noReadinessForTodayMeansNothingToSend() {
        #expect(AppModel.watchReadiness(summary: Self.summary(score: nil, verdict: nil), day: Self.day) == nil)
        #expect(AppModel.watchReadiness(summary: Self.summary(score: 63, verdict: nil), day: Self.day) == nil)
    }

    @Test func finishedGarminSyncPublishesReadiness() async throws {
        let server = FakeSyncServer()
        let app = try Self.app(remoteKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8", watchToken: WatchToken.generate(), server: server)

        await app.publishWatchReadiness(summary: Self.summary(score: 81, verdict: .hard), day: Self.day)

        #expect(server.bodies("PUT /api/v1/watch/readiness") == [#"{"day":"2026-11-12","score":81,"verdict":"Pode treinar forte"}"#])
    }

    @Test func finishedGarminSyncWithoutReadinessSendsNothing() async throws {
        let server = FakeSyncServer()
        let app = try Self.app(remoteKey: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8", watchToken: WatchToken.generate(), server: server)

        await app.publishWatchReadiness(summary: Self.summary(score: nil, verdict: nil), day: Self.day)
        await app.publishWatchReadiness(summary: nil, day: Self.day)

        #expect(server.requests.isEmpty)
    }

    @Test func remoteSyncOffSendsNothing() async throws {
        let server = FakeSyncServer()
        let app = try Self.app(remoteKey: nil, watchToken: WatchToken.generate(), server: server)

        await app.publishWatchReadiness(summary: Self.summary(score: 81, verdict: .hard), day: Self.day)

        #expect(server.requests.isEmpty)
    }
}
