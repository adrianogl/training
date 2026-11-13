import Foundation
import GarminAPI
import Storage
import Synchronization
import Testing
import TrainingCore
@testable import trAIning

private final class RouteTransport: HTTPTransport {
    private let routes: [String: String]
    let paths = Mutex<[String]>([])

    init(_ routes: [String: String]) {
        self.routes = routes
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let path = request.url?.path ?? ""
        paths.withLock { $0.append(path) }
        let body = routes.first { path.hasPrefix($0.key) }?.value
        return (Data((body ?? "").utf8), HTTPURLResponse(url: request.url!, statusCode: body == nil ? 404 : 200, httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor
@Suite struct TodayPlannedTests {
    @Test func plannedRunsOfTheWeekAndTodayPlan() async throws {
        let today = Day(year: 2026, month: 11, day: 13)
        let calendar = """
        {"calendarItems":[
         {"itemType":"workout","date":"2026-11-13","title":"Intervalado","workoutId":10,"sportTypeKey":"running"},
         {"itemType":"workout","date":"2026-11-15","title":"Longão","workoutId":11,"sportTypeKey":"running"},
         {"itemType":"workout","date":"2026-11-14","title":"Natação","workoutId":12,"sportTypeKey":"swimming"}
        ]}
        """
        let transport = RouteTransport([
            "/calendar-service/year/2026/month/10": calendar,
            "/workout-service/workout/10": #"{"workoutId":10,"workoutName":"Intervalado 5x1000","estimatedDistanceInMeters":9800,"estimatedDurationInSecs":3300,"workoutSegments":[]}"#,
            "/workout-service/workout/11": #"{"workoutId":11,"workoutName":"Longão 18 km","estimatedDistanceInMeters":18000,"estimatedDurationInSecs":6000,"workoutSegments":[]}"#,
        ])
        let keychain = MemoryKeyStore()
        let store = KeychainGarminSessionStore(keychain: keychain)
        try store.save(GarminAccountSession(accessToken: "t", refreshToken: "r", clientId: "C", expiresAt: .distantFuture))
        let client = GarminAccountClient(transport: transport, store: store)
        let model = TodayModel(container: try TrainingSchema.container(inMemory: true), today: today)

        await model.loadPlanned(client: client)

        #expect(model.todayPlan?.title == "Intervalado 5x1000")
        #expect(model.planned[Day(year: 2026, month: 11, day: 15)]?.map(\.estimatedMeters) == [18_000])
        #expect(model.planned[Day(year: 2026, month: 11, day: 14)] == nil)
        #expect(!transport.paths.withLock { $0 }.contains("/workout-service/workout/12"))
    }

    @Test func withoutAccountNothingIsLoaded() async throws {
        let model = TodayModel(container: try TrainingSchema.container(inMemory: true), today: Day(year: 2026, month: 11, day: 13))
        await model.loadPlanned(client: nil)
        #expect(model.planned.isEmpty)
        #expect(model.todayPlan == nil)
    }

    @Test func plannedHistoryIsCachedForClosedWeeks() async throws {
        let today = Day(year: 2026, month: 11, day: 13)
        let defaults = try #require(UserDefaults(suiteName: "planned-history-test"))
        defaults.removePersistentDomain(forName: "planned-history-test")
        let calendar = #"{"calendarItems":[{"itemType":"workout","date":"2026-10-01","title":"Longão","workoutId":21,"sportTypeKey":"running"}]}"#
        let transport = RouteTransport([
            "/calendar-service/year/2026/month/8": calendar,
            "/calendar-service/year/2026/month/10": #"{"calendarItems":[]}"#,
            "/workout-service/workout/21": #"{"workoutId":21,"workoutName":"Longão","estimatedDistanceInMeters":12000,"workoutSegments":[]}"#,
        ])
        let store = KeychainGarminSessionStore(keychain: MemoryKeyStore())
        try store.save(GarminAccountSession(accessToken: "t", refreshToken: "r", clientId: "C", expiresAt: .distantFuture))
        let container = try TrainingSchema.container(inMemory: true)

        let first = TodayModel(container: container, today: today)
        await first.load()
        await first.loadPlannedHistory(client: GarminAccountClient(transport: transport, store: store), defaults: defaults)
        #expect(first.plannedWeeks[Day(year: 2026, month: 9, day: 28)] == 12)

        let offline = RouteTransport([:])
        let second = TodayModel(container: container, today: today)
        await second.load()
        await second.loadPlannedHistory(client: GarminAccountClient(transport: offline, store: store), defaults: defaults)
        #expect(second.plannedWeeks[Day(year: 2026, month: 9, day: 28)] == 12)
        #expect(offline.paths.withLock { $0 }.isEmpty)
    }
}
