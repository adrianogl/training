import Foundation
import Synchronization
import Testing
import TrainingCore
@testable import GarminAPI

private func fixture(_ name: String) -> String {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try! String(contentsOf: url, encoding: .utf8)
}

private final class SleepLog: Sendable {
    private let items = Mutex<[Duration]>([])
    func record(_ duration: Duration) { items.withLock { $0.append(duration) } }
    var all: [Duration] { items.withLock { $0 } }
}

private struct Harness {
    let client: GarminClient
    let stub: StubTransport
    let tokenStub: StubTransport
    let sleeps: SleepLog
}

private func makeClient(responses: [StubTransport.Response], tokenCount: Int = 1, now: Date = .now) -> Harness {
    let exp = Int(Date.now.timeIntervalSince1970) + 86_400 * 365
    let tokenStub = StubTransport(Array(repeating: .ok(makeJWT(exp: exp)), count: tokenCount))
    let stub = StubTransport(responses)
    let tokens = TokenProvider(apiKey: "k", baseURL: GarminEndpoints.base, transport: tokenStub)
    let sleeps = SleepLog()
    let client = GarminClient(
        tokens: tokens,
        transport: stub,
        sleep: { duration in sleeps.record(duration) },
        now: { now }
    )
    return Harness(client: client, stub: stub, tokenStub: tokenStub, sleeps: sleeps)
}

private func day(_ iso: String) -> Day { Day(iso: iso)! }

private func httpDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "GMT")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
    return formatter.string(from: date)
}

private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

@Suite struct GarminClientTests {
    @Test func splitsHrvRangeIn180DayWindows() async throws {
        let h = makeClient(responses: [.ok(fixture("hrv")), .ok(fixture("hrv"))])
        _ = try await h.client.hrvSummaries(from: day("2026-01-01"), to: day("2026-08-01"))
        #expect(h.stub.getPaths.filter { $0.hasPrefix("/hrv-service/hrv/daily/") }.count == 2)
        #expect(h.stub.getPaths.first == "/hrv-service/hrv/daily/2026-01-01/2026-06-29")
    }

    @Test func splitsSleepRangeIn28DayWindows() async throws {
        let h = makeClient(responses: [.ok("[]"), .ok("[]"), .ok("[]")])
        _ = try await h.client.sleepSummaries(from: day("2026-01-01"), to: day("2026-03-01"))
        let queries = h.stub.requests.map { $0.url?.query ?? "" }
        #expect(h.stub.getPaths.count == 3)
        #expect(queries.first == "startDate=2026-01-01&endDate=2026-01-28")
        #expect(queries.last == "startDate=2026-02-26&endDate=2026-03-01")
    }

    @Test func emptyBodyMeansEmptyList() async throws {
        let h = makeClient(responses: [.status(204, "")])
        let result = try await h.client.hrvSummaries(from: day("2023-06-01"), to: day("2023-06-30"))
        #expect(result.isEmpty)
    }

    @Test func decodesHrvWithNullsAndBaseline() async throws {
        let h = makeClient(responses: [.ok(fixture("hrv"))])
        let result = try await h.client.hrvSummaries(from: day("2026-01-01"), to: day("2026-01-02"))
        #expect(result.count == 2)
        #expect(result[0].lastNightAvg == 49 && result[0].baselineBalancedLow == 45 && result[0].status == "BALANCED")
        #expect(result[1].lastNightAvg == nil && result[1].baselineLowUpper == nil)
    }

    @Test func decodesDailySummariesFromDataEnvelope() async throws {
        let h = makeClient(responses: [.ok(fixture("dailysummaries"))])
        let result = try await h.client.dailySummaries(from: day("2026-11-04"), to: day("2026-11-05"))
        #expect(result[0].restingHeartRate == 51 && result[0].avgStress == 27)
        #expect(result[0].bodyBatteryMin == 12 && result[0].bodyBatteryMax == 95 && result[0].avgRespiration == 14.5)
        #expect(result[0].moderateIntensityMinutes == 30 && result[0].vigorousIntensityMinutes == 20)
        #expect(result[1].restingHeartRate == 52 && result[1].avgStress == nil)
    }

    @Test func decodesSleepIncludingMissingScores() async throws {
        let h = makeClient(responses: [.ok(fixture("sleep"))])
        let result = try await h.client.sleepSummaries(from: day("2026-11-05"), to: day("2026-11-06"))
        #expect(result[0].overallScore == 82 && result[0].deepSleepSeconds == 5400)
        #expect(result[0].sleepEndTimestampGMT == 1_793_000_000_000 && result[0].sleepEndTimestampLocal == 1_792_989_200_000)
        #expect(result[1].overallScore == nil && result[1].remSleepSeconds == nil)
    }

    @Test func decodesBodyBatteryWithNullValue() async throws {
        let h = makeClient(responses: [.ok(fixture("bodybattery"))])
        let result = try await h.client.bodyBattery(from: day("2026-11-05"), to: day("2026-11-05"))
        #expect(result[0].samples.count == 3)
        #expect(result[0].samples[0] == BodyBatterySampleDTO(timestampMs: 1_793_000_000_000, value: 30))
        #expect(result[0].samples[1].value == nil)
        #expect(result[0].charged == 60)
    }

    @Test func dropsBodyBatterySamplesOutOfRange() async throws {
        let body = #"[{"date": "2026-11-05", "bodyBatteryValuesArray": [[1e300, 30], [1793000000000, 1e30], [1793000900000.4, 40.6], [-1e19, 50]]}]"#
        let h = makeClient(responses: [.ok(body)])
        let result = try await h.client.bodyBattery(from: day("2026-11-05"), to: day("2026-11-05"))
        #expect(result[0].samples == [BodyBatterySampleDTO(timestampMs: 1_793_000_900_000, value: 41)])
    }

    @Test func picksDefaultHeartRateZones() async throws {
        let h = makeClient(responses: [.ok(fixture("hrzones"))])
        let zones = try await h.client.heartRateZones()
        #expect(zones.maxHeartRateUsed == 191 && zones.zone1Floor == 121 && zones.restingHeartRateUsed == 51)
        #expect(zones.lactateThresholdHeartRateUsed == 166)
    }

    @Test func missingDefaultZoneIsDecodingError() async {
        let h = makeClient(responses: [.ok("[]")])
        await #expect(throws: GarminAPIError.decoding(path: GarminEndpoints.heartRateZonesPath)) {
            try await h.client.heartRateZones()
        }
    }

    @Test func decodesActivityFields() async throws {
        let h = makeClient(responses: [.ok(fixture("activities"))])
        let list = try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        let a = list.first!
        #expect(a.typeKey == "running" && a.activityTrainingLoad == 139.2 && a.hrTimeInZone == [70.2, 300, 900, 1000, 126])
        #expect(a.activityId == 9_000_000_001 && a.startTimeLocal == "2026-11-05 19:43:34" && a.pr == true)
        let strength = list[1]
        #expect(strength.typeKey == "strength_training" && strength.avgPower == nil && strength.hrTimeInZone == nil)
    }

    @Test func activitiesSendsPagingQuery() async throws {
        let h = makeClient(responses: [.ok("[]")])
        _ = try await h.client.activities(start: 50, limit: 50, from: day("2026-01-01"), to: nil)
        let query = h.stub.requests[0].url?.query ?? ""
        #expect(query.contains("start=50") && query.contains("limit=50") && query.contains("startDate=2026-01-01"))
    }

    @Test func getSendsJsonAcceptAndBearer() async throws {
        let h = makeClient(responses: [.ok("[]")])
        _ = try await h.client.activities(start: 0, limit: 1, from: nil, to: nil)
        let request = h.stub.requests[0]
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true)
    }

    @Test func fitDownloadSendsAcceptAny() async throws {
        let h = makeClient(responses: [.ok("PK-bytes")])
        let data = try await h.client.fitArchive(activityId: 9_000_000_001)
        #expect(h.stub.requests[0].value(forHTTPHeaderField: "Accept") == "*/*")
        #expect(h.stub.getPaths == ["/download-service/files/activity/9000000001"])
        #expect(data == Data("PK-bytes".utf8))
    }

    @Test func retriesOn429ThenSucceeds() async throws {
        let h = makeClient(responses: [.status(429, ""), .ok(fixture("sleep"))])
        let result = try await h.client.sleepSummaries(from: day("2026-11-05"), to: day("2026-11-06"))
        #expect(result.count == 2)
        #expect(h.sleeps.all == [.seconds(30)])
    }

    @Test func honorsRetryAfterSeconds() async throws {
        let h = makeClient(responses: [.status(429, "", headers: ["Retry-After": "12"]), .ok("[]")])
        let result = try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        #expect(result.isEmpty)
        #expect(h.sleeps.all == [.seconds(12)])
    }

    @Test func capsRetryAfterSeconds() async throws {
        let h = makeClient(responses: [.status(429, "", headers: ["Retry-After": "3600"]), .ok("[]")])
        _ = try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        #expect(h.sleeps.all == [.seconds(300)])
    }

    @Test(arguments: [(45.0, 45), (3_600.0, 300), (-60.0, 30)])
    func honorsRetryAfterHTTPDate(offset: TimeInterval, expectedSeconds: Int) async throws {
        let header = httpDate(fixedNow.addingTimeInterval(offset))
        let h = makeClient(responses: [.status(429, "", headers: ["Retry-After": header]), .ok("[]")], now: fixedNow)
        _ = try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        #expect(h.sleeps.all == [.seconds(expectedSeconds)])
    }

    @Test(arguments: ["0", "-5"])
    func nonPositiveRetryAfterFallsBackToSchedule(header: String) async throws {
        let h = makeClient(responses: [.status(429, "", headers: ["Retry-After": header]), .ok("[]")])
        _ = try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        #expect(h.sleeps.all == [.seconds(30)])
    }

    @Test func readsLowercaseRetryAfter() async throws {
        let h = makeClient(responses: [.status(429, "", headers: ["retry-after": "45"]), .ok("[]")])
        _ = try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        #expect(h.sleeps.all == [.seconds(45)])
    }

    @Test func ignoresRetryAfterOnServerError() async throws {
        let h = makeClient(responses: [.status(503, "", headers: ["Retry-After": "99"]), .ok("[]")])
        _ = try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        #expect(h.sleeps.all == [.seconds(1)])
    }

    @Test func retriesTransientTransportErrors() async throws {
        let h = makeClient(responses: [.failure(.timedOut), .failure(.networkConnectionLost), .ok("[]")])
        _ = try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        #expect(h.sleeps.all == [.seconds(1), .seconds(2)])
    }

    @Test func offlineGivesUpAfterRetries() async {
        let h = makeClient(responses: Array(repeating: .failure(.notConnectedToInternet), count: 4))
        await #expect(throws: URLError(.notConnectedToInternet)) {
            try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        }
        #expect(h.sleeps.all == [.seconds(1), .seconds(2), .seconds(4)])
    }

    @Test(arguments: [403, 404, 410])
    func clientErrorKeepsStatusAndPath(status: Int) async {
        let h = makeClient(responses: [.status(status, "")])
        await #expect(throws: GarminAPIError.client(status: status, path: GarminEndpoints.activitiesPath)) {
            try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        }
        #expect(h.sleeps.all.isEmpty)
    }

    @Test func invalidRetryAfterFallsBackToSchedule() async throws {
        let h = makeClient(responses: [.status(429, "", headers: ["Retry-After": "soon"]), .ok("[]")])
        _ = try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        #expect(h.sleeps.all == [.seconds(30)])
    }

    @Test func backsOffExponentiallyThenGivesUp() async {
        let h = makeClient(responses: Array(repeating: .status(503, ""), count: 4))
        await #expect(throws: GarminAPIError.server(status: 503)) {
            try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        }
        #expect(h.sleeps.all == [.seconds(1), .seconds(2), .seconds(4)])
    }

    @Test func persistent429BacksOffThenIsRateLimitedWithPath() async {
        let h = makeClient(responses: Array(repeating: .status(429, ""), count: 4))
        await #expect(throws: GarminAPIError.rateLimited(path: GarminEndpoints.activitiesPath)) {
            try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        }
        #expect(h.sleeps.all == [.seconds(30), .seconds(60), .seconds(120)])
        #expect(h.stub.requests.count == 4)
    }

    @Test func gives400AsBadRequest() async {
        let h = makeClient(responses: [.status(400, "")])
        await #expect(throws: GarminAPIError.badRequest(path: GarminEndpoints.activitiesPath)) {
            try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        }
        #expect(h.sleeps.all.isEmpty)
    }

    @Test func gives406AsNotAcceptable() async {
        let h = makeClient(responses: [.status(406, "")])
        await #expect(throws: GarminAPIError.notAcceptable) {
            try await h.client.fitArchive(activityId: 1)
        }
    }

    @Test func malformedBodyIsDecodingError() async {
        let h = makeClient(responses: [.ok("{\"nope\": 1}")])
        await #expect(throws: GarminAPIError.decoding(path: GarminEndpoints.activitiesPath)) {
            try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        }
    }

    @Test func unauthorizedInvalidatesTokenOnceThenSucceeds() async throws {
        let h = makeClient(responses: [.status(401, ""), .ok("[]")], tokenCount: 2)
        let result = try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        #expect(result.isEmpty)
        #expect(h.tokenStub.requests.count == 2)
        #expect(h.stub.requests.count == 2)
    }

    @Test func secondUnauthorizedIsUnauthorized() async {
        let h = makeClient(responses: [.status(401, ""), .status(401, "")], tokenCount: 2)
        await #expect(throws: GarminAPIError.unauthorized) {
            try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        }
        #expect(h.tokenStub.requests.count == 2)
        #expect(h.stub.requests.count == 2)
    }

    @Test func dailySummariesSendsStartAndEndDate() async throws {
        let h = makeClient(responses: [.ok(fixture("dailysummaries"))])
        _ = try await h.client.dailySummaries(from: day("2026-11-04"), to: day("2026-11-05"))
        #expect(h.stub.getPaths == ["/usersummary-service/v2/dailysummaries"])
        #expect(h.stub.requests[0].url?.query == "startDate=2026-11-04&endDate=2026-11-05")
    }

    @Test func skipsInvalidItemsAndKeepsTheRest() async throws {
        let body = """
        {"data": [
          {"calendarDate": "2026-11-04", "heartRate": {"restingValue": 51}},
          {"heartRate": {"restingValue": 50}},
          {"calendarDate": "not-a-date"},
          {"calendarDate": "2026-11-06", "heartRate": {"restingValue": "x"}},
          {"calendarDate": "2026-11-07", "heartRate": {"restingValue": 49}}
        ]}
        """
        let h = makeClient(responses: [.ok(body)])
        let result = try await h.client.dailySummaries(from: day("2026-11-04"), to: day("2026-11-07"))
        #expect(result.map(\.day.iso) == ["2026-11-04", "2026-11-07"])
    }

    @Test func skipsInvalidItemsInTopLevelArray() async throws {
        let body = #"[{"calendarDate": "2026-11-05", "sleepTimeSeconds": 100}, {"sleepTimeSeconds": 5}, 42]"#
        let h = makeClient(responses: [.ok(body)])
        let result = try await h.client.sleepSummaries(from: day("2026-11-05"), to: day("2026-11-05"))
        #expect(result.count == 1 && result[0].sleepTimeSeconds == 100)
    }

    @Test func roundsFractionalNumbersInIntegerFields() async throws {
        let body = """
        {"data": [{"calendarDate": "2026-11-04", "heartRate": {"restingValue": 51.5},
          "stress": {"avgLevel": 26.4}, "bodyBattery": {"minValue": 11.6, "maxValue": 95.0},
          "intensityMinutes": {"moderate": 30.5, "vigorous": 0.4}}]}
        """
        let h = makeClient(responses: [.ok(body)])
        let r = try await h.client.dailySummaries(from: day("2026-11-04"), to: day("2026-11-04"))[0]
        #expect(r.restingHeartRate == 52 && r.avgStress == 26 && r.bodyBatteryMin == 12 && r.bodyBatteryMax == 95)
        #expect(r.moderateIntensityMinutes == 31 && r.vigorousIntensityMinutes == 0)
    }

    @Test func roundsFractionalSleepAndBodyBatteryIntegers() async throws {
        let sleep = makeClient(responses: [.ok(#"[{"calendarDate": "2026-11-05", "sleepTimeSeconds": 27000.6, "sleepEndTimestampGMT": 1793000000000.4}]"#)])
        let s = try await sleep.client.sleepSummaries(from: day("2026-11-05"), to: day("2026-11-05"))[0]
        #expect(s.sleepTimeSeconds == 27001 && s.sleepEndTimestampGMT == 1_793_000_000_000)
        let battery = makeClient(responses: [.ok(#"[{"date": "2026-11-05", "charged": 60.5, "drained": 44.4}]"#)])
        let b = try await battery.client.bodyBattery(from: day("2026-11-05"), to: day("2026-11-05"))[0]
        #expect(b.charged == 61 && b.drained == 44)
    }

    @Test func unparseableEnvelopeIsDecodingError() async {
        let h = makeClient(responses: [.ok("[1, 2]")])
        await #expect(throws: GarminAPIError.decoding(path: GarminEndpoints.dailySummariesPath)) {
            try await h.client.dailySummaries(from: day("2026-11-04"), to: day("2026-11-04"))
        }
    }
}

@Suite struct GarminClientBackgroundTests {
    @Test func clientFailsFastOnRateLimitWhenAsked() async {
        let exp = Int(Date.now.timeIntervalSince1970) + 86_400 * 365
        let tokenStub = StubTransport([.ok(makeJWT(exp: exp))])
        let stub = StubTransport([.status(429, ""), .ok("[]")])
        let tokens = TokenProvider(apiKey: "k", baseURL: GarminEndpoints.base, transport: tokenStub)
        let sleeps = SleepLog()
        let client = GarminClient(tokens: tokens, transport: stub, sleep: { sleeps.record($0) }, waitsOnRateLimit: false)

        await #expect(throws: GarminAPIError.rateLimited(path: GarminEndpoints.activitiesPath)) {
            try await client.activities(start: 0, limit: 50, from: nil, to: nil)
        }
        #expect(sleeps.all.isEmpty)
        #expect(stub.requests.count == 1)
    }
}
