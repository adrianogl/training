import FITReader
import Foundation
import GarminAPI
import RemoteSync
import Storage
import SwiftData
import Synchronization
import Testing
@testable import trAIning

private final class StravaTransport: HTTPTransport {
    private let replies: Mutex<[(Int, String)]>
    private let sent = Mutex<[URLRequest]>([])

    init(_ replies: [(Int, String)]) {
        self.replies = Mutex(replies)
    }

    var requests: [URLRequest] { sent.withLock { $0 } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        sent.withLock { $0.append(request) }
        let (status, body) = replies.withLock { $0.isEmpty ? (500, "") : $0.removeFirst() }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private struct NoAuth: StravaWebAuthenticating {
    func authenticate(url: URL) async throws -> URL { url }
}

@Suite struct StravaSendLedgerTests {
    private let start = Date(timeIntervalSince1970: 1_793_000_000)

    @Test func newRunIsAttemptedAndSentRunIsNot() {
        var ledger = StravaSendLedger()
        #expect(ledger.shouldAttempt(1, runStart: start, now: start.addingTimeInterval(600)))

        ledger.record(.posted, activityId: 1, now: start.addingTimeInterval(600))

        #expect(ledger.isSent(1))
        #expect(!ledger.shouldAttempt(1, runStart: start, now: start.addingTimeInterval(7_200)))
    }

    @Test func notFoundWaitsFifteenMinutesAndGivesUpAfterADay() {
        var ledger = StravaSendLedger()
        let first = start.addingTimeInterval(600)
        ledger.record(.notFound, activityId: 1, now: first)

        #expect(!ledger.shouldAttempt(1, runStart: start, now: first.addingTimeInterval(300)))
        #expect(ledger.shouldAttempt(1, runStart: start, now: first.addingTimeInterval(901)))
        #expect(!ledger.shouldAttempt(1, runStart: start, now: start.addingTimeInterval(25 * 3_600)))
    }

    @Test func editedAndDisabledOutcomes() {
        var ledger = StravaSendLedger()
        let now = start.addingTimeInterval(600)

        ledger.record(.editedByUser, activityId: 1, now: now)
        ledger.record(.disabled, activityId: 2, now: now)

        #expect(!ledger.shouldAttempt(1, runStart: start, now: now.addingTimeInterval(3_600)))
        #expect(ledger.entry(2) == nil)
        #expect(ledger.shouldAttempt(2, runStart: start, now: now))
    }

    @Test func retryLaterKeepsItPending() {
        var ledger = StravaSendLedger()
        ledger.record(.retryLater, activityId: 1, now: start)

        #expect(ledger.entry(1)?.status == .pending)
    }
}

@MainActor
@Suite struct StravaModelTests {
    private typealias F = WorkoutDetailFixtures

    private static let status = #"{"connected":true,"athleteName":"Adriano G","format":"B","enabled":true}"#

    private func model(_ transport: StravaTransport, defaults: UserDefaults, container: ModelContainer) -> StravaModel {
        let model = StravaModel(container: container, defaults: defaults, authenticator: NoAuth(), now: { F.base.addingTimeInterval(3_600) })
        model.link = { StravaClient(baseURL: URL(string: "https://sync.example.test")!, token: "sessao", transport: transport) }
        return model
    }

    private func container(fitProcessed: Bool = true) throws -> ModelContainer {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        let run = F.run(id: 1, meters: 5_900, workoutName: "Tiros 3 x 1 km", structure: F.intervalStructure())
        run.fitProcessed = fitProcessed
        context.insert(run)
        try context.save()
        return container
    }

    @Test func blockSizesUseKilometersWhenLongEnough() {
        #expect(StravaSummaryLoader.blockSize(.distance(meters: 1_000)) == "1 km")
        #expect(StravaSummaryLoader.blockSize(.distance(meters: 1_500)) == "1,5 km")
        #expect(StravaSummaryLoader.blockSize(.distance(meters: 400)) == "400 m")
        #expect(StravaSummaryLoader.blockSize(.time(seconds: 600)) == "10 min")
    }

    @Test func payloadFromARunHasTheHeadlineAndSignature() throws {
        let container = try container()

        let payload = try #require(StravaSummaryLoader.payload(activityId: 1, in: ModelContext(container)))

        #expect(payload.text.hasPrefix("VO2 máx | 3 × 1 km @ 4:05/km"))
        #expect(payload.text.hasSuffix("\nvia https://training.aglv.dev"))
        #expect(payload.distanceMeters == 5_900)
    }

    @Test func pendingPassSendsOnceAndRemembersIt() async throws {
        let defaults = UserDefaults(suiteName: "strava-\(UUID().uuidString)")!
        let transport = StravaTransport([(200, Self.status), (200, #"{"status":"posted","stravaActivityId":9}"#)])
        let strava = model(transport, defaults: defaults, container: try container())

        await strava.refreshStatus()
        await strava.sendPending()
        await strava.sendPending()

        #expect(strava.ledger.isSent(1))
        #expect(transport.requests.map { "\($0.httpMethod ?? "") \($0.url?.path ?? "")" } == ["GET /api/v1/strava", "POST /api/v1/strava/describe"])
        let reloaded = StravaModel(container: try container(), defaults: defaults, authenticator: NoAuth())
        #expect(reloaded.ledger.isSent(1))
    }

    @Test func notFoundStaysPendingAndManualResendReportsIt() async throws {
        let transport = StravaTransport([(200, Self.status), (200, #"{"status":"not_found"}"#), (200, #"{"status":"edited_by_user"}"#)])
        let strava = model(transport, defaults: UserDefaults(suiteName: "strava-\(UUID().uuidString)")!, container: try container())

        await strava.refreshStatus()
        await strava.sendPending()
        let manual = await strava.send(activityId: 1)

        #expect(strava.ledger.entry(1)?.status == .editedByUser)
        #expect(manual == .editedByUser)
        #expect(manual.message == "Você editou o texto no Strava; não mexemos")
    }

    @Test func disabledToggleStopsTheAutomaticPass() async throws {
        let transport = StravaTransport([(200, #"{"connected":true,"athleteName":"A","format":"B","enabled":false}"#)])
        let strava = model(transport, defaults: UserDefaults(suiteName: "strava-\(UUID().uuidString)")!, container: try container())

        await strava.refreshStatus()
        await strava.sendPending()

        #expect(transport.requests.count == 1)
    }

    @Test func manualSendWithoutConnectionSaysSo() async throws {
        let strava = model(StravaTransport([]), defaults: UserDefaults(suiteName: "strava-\(UUID().uuidString)")!, container: try container())

        #expect(await strava.send(activityId: 1) == .notConnected)
    }
}
