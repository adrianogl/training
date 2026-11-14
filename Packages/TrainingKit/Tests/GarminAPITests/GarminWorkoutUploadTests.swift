import Foundation
import Synchronization
import Testing
import TrainingCore
@testable import GarminAPI

private final class UploadStore: GarminSessionStore {
    let session: GarminAccountSession

    init(_ session: GarminAccountSession) {
        self.session = session
    }

    func load() throws -> GarminAccountSession? { session }
    func save(_ session: GarminAccountSession) throws {}
}

@Suite struct GarminWorkoutUploadTests {
    @Test func payloadHasOneDistanceStepPerKmWithPaceRange() throws {
        let data = try GarminWorkoutUpload.payload(name: "LIVE!21K · estratégia", steps: [
            UploadStep(meters: 1_000, fastestSecondsPerKm: 256, slowestSecondsPerKm: 266),
            UploadStep(meters: 97.5, fastestSecondsPerKm: 250, slowestSecondsPerKm: 260),
        ])
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let segment = try #require((json["workoutSegments"] as? [[String: Any]])?.first)
        let steps = try #require(segment["workoutSteps"] as? [[String: Any]])

        #expect(json["workoutName"] as? String == "LIVE!21K · estratégia")
        #expect(steps.count == 2)
        #expect(steps[1]["endConditionValue"] as? Double == 97.5)
        #expect(abs((steps[0]["targetValueOne"] as? Double ?? 0) - 1_000.0 / 266) < 0.0001)
        #expect(abs((steps[0]["targetValueTwo"] as? Double ?? 0) - 1_000.0 / 256) < 0.0001)
    }

    @Test func uploadCreatesThenSchedulesOnRaceDay() async throws {
        let session = GarminAccountSession(accessToken: "token", refreshToken: "refresh", clientId: "C", expiresAt: .distantFuture)
        let stub = StubTransport([.ok(#"{"workoutId": 987}"#), .ok("{}")])
        let client = GarminAccountClient(transport: stub, store: UploadStore(session))

        let id = try await GarminWorkoutUpload.upload(
            client: client, name: "Prova", steps: [UploadStep(meters: 1_000, fastestSecondsPerKm: 256, slowestSecondsPerKm: 266)],
            day: Day(iso: "2026-11-22")!
        )

        #expect(id == 987)
        #expect(stub.requests.map { $0.httpMethod ?? "" } == ["POST", "POST"])
        #expect(stub.requests.map { $0.url?.path ?? "" } == ["/workout-service/workout", "/workout-service/schedule/987"])
        #expect(String(decoding: stub.requests[1].httpBody ?? Data(), as: UTF8.self) == #"{"date":"2026-11-22"}"#)
    }
}
