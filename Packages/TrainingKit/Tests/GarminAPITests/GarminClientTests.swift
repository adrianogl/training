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

private func makeClient(responses: [StubTransport.Response], tokenCount: Int = 1) -> Harness {
    let exp = Int(Date.now.timeIntervalSince1970) + 86_400 * 365
    let tokenStub = StubTransport(Array(repeating: .ok(makeJWT(exp: exp)), count: tokenCount))
    let stub = StubTransport(responses)
    let tokens = TokenProvider(apiKey: "k", baseURL: GarminEndpoints.base, transport: tokenStub)
    let sleeps = SleepLog()
    let client = GarminClient(tokens: tokens, transport: stub) { duration in
        sleeps.record(duration)
    }
    return Harness(client: client, stub: stub, tokenStub: tokenStub, sleeps: sleeps)
}

private func day(_ iso: String) -> Day { Day(iso: iso)! }

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
        #expect(h.stub.getPaths.count == 3)
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
        #expect(h.sleeps.all == [.seconds(1)])
    }

    @Test func backsOffExponentiallyThenGivesUp() async {
        let h = makeClient(responses: Array(repeating: .status(503, ""), count: 4))
        await #expect(throws: GarminAPIError.server(status: 503)) {
            try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        }
        #expect(h.sleeps.all == [.seconds(1), .seconds(2), .seconds(4)])
    }

    @Test func persistent429IsRateLimited() async {
        let h = makeClient(responses: Array(repeating: .status(429, ""), count: 4))
        await #expect(throws: GarminAPIError.rateLimited) {
            try await h.client.activities(start: 0, limit: 50, from: nil, to: nil)
        }
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
}
