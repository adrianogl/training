import Foundation
import Testing
@testable import GarminAPI

private final class FixedStore: GarminSessionStore {
    func load() throws -> GarminAccountSession? {
        GarminAccountSession(accessToken: "token", refreshToken: "refresh", clientId: "C", expiresAt: .distantFuture)
    }

    func save(_ session: GarminAccountSession) throws {}
}

private let start = Date(timeIntervalSince1970: 1_795_900_000)

private let sets: [ExerciseSetUpload] = [
    .active(category: "BENCH_PRESS", exerciseKey: "INCLINE_DUMBBELL_BENCH_PRESS", reps: 10, weightKg: 22.5, start: start, durationSeconds: 42),
    .rest(start: start.addingTimeInterval(42), durationSeconds: 90),
    .active(category: "PUSH_UP", exerciseKey: "PUSH_UP", reps: 15, weightKg: nil, start: start.addingTimeInterval(132), durationSeconds: 35),
    .active(category: "PLANK", exerciseKey: nil, reps: nil, weightKg: nil, start: start.addingTimeInterval(167), durationSeconds: 45),
]

@Suite struct ExerciseSetsUploadTests {
    @Test func payloadUsesGramsUtcStartAndNullsForMissingValues() throws {
        let data = try ExerciseSetsUpload.payload(activityId: 42, sets: sets)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let body = try #require(json["exerciseSets"] as? [[String: Any]])

        #expect(json["activityId"] as? Int64 == 42)
        #expect(body.map { $0["setType"] as? String } == ["ACTIVE", "REST", "ACTIVE", "ACTIVE"])
        #expect(body[0]["weight"] as? Double == 22_500)
        #expect(body[0]["startTime"] as? String == "2026-11-28T21:06:40.0")
        #expect(body[1]["startTime"] as? String == "2026-11-28T21:07:22.0")
        #expect((body[1]["exercises"] as? [Any])?.isEmpty == true)
        #expect(body[1]["repetitionCount"] is NSNull)
        #expect(body[2]["weight"] is NSNull)
        #expect(body[3]["duration"] as? Double == 45)
        #expect(((body[3]["exercises"] as? [[String: Any]])?.first?["name"]) is NSNull)
    }

    @Test func payloadReadsBackAsTheSameActiveSets() throws {
        let data = try ExerciseSetsUpload.payload(activityId: 42, sets: sets)
        #expect(try ExerciseSets.parse(data) == [
            StrengthSet(category: "BENCH_PRESS", exerciseKey: "INCLINE_DUMBBELL_BENCH_PRESS", reps: 10, weight: 22.5),
            StrengthSet(category: "PUSH_UP", exerciseKey: "PUSH_UP", reps: 15, weight: nil),
            StrengthSet(category: "PLANK", exerciseKey: nil, reps: nil, weight: nil),
        ])
    }

    @Test func uploadPutsOnTheActivityExerciseSets() async throws {
        let stub = StubTransport([.ok("")])
        let client = GarminAccountClient(transport: stub, store: FixedStore())

        try await ExerciseSetsUpload.upload(client: client, activityId: 987, sets: sets)

        #expect(stub.requests.map { $0.httpMethod ?? "" } == ["PUT"])
        #expect(stub.requests.first?.url?.path == "/activity-service/activity/987/exerciseSets")
        #expect(stub.requests.first?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func uploadSurfacesRejection() async throws {
        let stub = StubTransport([.status(403, "")])
        let client = GarminAccountClient(transport: stub, store: FixedStore())

        await #expect(throws: GarminAccountError.unexpectedResponse(status: 403)) {
            try await ExerciseSetsUpload.upload(client: client, activityId: 987, sets: sets)
        }
    }
}
