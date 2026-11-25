import Foundation
import Testing
import TrainingCore
@testable import GarminAPI

private final class PlannedStore: GarminSessionStore {
    func load() throws -> GarminAccountSession? {
        GarminAccountSession(accessToken: "token", refreshToken: "refresh", clientId: "C", expiresAt: .distantFuture)
    }
    func save(_ session: GarminAccountSession) throws {}
}

@Suite struct GarminPlannedUploadTests {
    private func json(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func steps(_ body: [String: Any]) throws -> [[String: Any]] {
        try #require((body["workoutSegments"] as? [[String: Any]])?.first?["workoutSteps"] as? [[String: Any]])
    }

    @Test func heartRateGoesAsSecondaryWithPaceOnEveryStep() throws {
        let data = try GarminPlannedPayload.running(name: "Limiar", steps: [
            .warmup(meters: 4_000, fastest: 320, slowest: 334, heartRate: 146...154),
            .interval(meters: 2_000, fastest: 243, slowest: 249, heartRate: 163...171),
            .cooldown(meters: 1_000, fastest: 320, slowest: 334, heartRate: 146...154),
        ])
        let list = try steps(try json(data))
        #expect((list[0]["targetType"] as? [String: Any])?["workoutTargetTypeKey"] as? String == "pace.zone")
        #expect(list[0]["targetValueOne"] as? Double == 1_000.0 / 334)
        #expect(list[0]["targetValueTwo"] as? Double == 1_000.0 / 320)
        #expect((list[0]["secondaryTargetType"] as? [String: Any])?["workoutTargetTypeKey"] as? String == "heart.rate.zone")
        #expect(list[0]["secondaryTargetValueOne"] as? Double == 146)
        #expect((list[1]["targetType"] as? [String: Any])?["workoutTargetTypeKey"] as? String == "pace.zone")
        #expect((list[1]["secondaryTargetType"] as? [String: Any])?["workoutTargetTypeKey"] as? String == "heart.rate.zone")
        #expect(list[1]["secondaryTargetValueTwo"] as? Double == 171)
        #expect((list[2]["targetType"] as? [String: Any])?["workoutTargetTypeKey"] as? String == "pace.zone")
        #expect(list[2]["secondaryTargetValueTwo"] as? Double == 154)
    }

    @Test func runningPayloadHasWarmupRepeatAndRest() throws {
        let data = try GarminPlannedPayload.running(name: "Limiar", steps: [
            .warmup(meters: 3_000),
            .repeated(times: 8, steps: [.interval(meters: 1_000, fastest: 240, slowest: 248), .rest(seconds: 120)]),
        ])
        let body = try json(data)
        let list = try steps(body)
        #expect((body["sportType"] as? [String: Any])?["sportTypeKey"] as? String == "running")
        #expect((list[0]["stepType"] as? [String: Any])?["stepTypeKey"] as? String == "warmup")
        #expect(list[0]["endConditionValue"] as? Double == 3_000)
        #expect(list[1]["type"] as? String == "RepeatGroupDTO")
        #expect(list[1]["numberOfIterations"] as? Int == 8)
        let inner = try #require(list[1]["workoutSteps"] as? [[String: Any]])
        #expect(abs((inner[0]["targetValueOne"] as? Double ?? 0) - 1_000.0 / 248) < 0.0001)
        #expect((inner[1]["stepType"] as? [String: Any])?["stepTypeKey"] as? String == "rest")
        #expect((inner[1]["endCondition"] as? [String: Any])?["conditionTypeKey"] as? String == "time")
        #expect(inner[1]["endConditionValue"] as? Double == 120)
    }

    @Test func strengthPayloadRepeatsSetsWithRestAndGarminKeys() throws {
        let data = try GarminPlannedPayload.strength(name: "Pernas", exercises: [
            PlannedStrengthExercise(description: "Agachamento livre", category: "SQUAT", exerciseName: "BARBELL_BACK_SQUAT", sets: 4, reps: 6, seconds: nil, restSeconds: 150, weight: 62),
            PlannedStrengthExercise(description: "Prancha lateral - cada lado", category: "PLANK", exerciseName: nil, sets: 3, reps: nil, seconds: 30, restSeconds: 30, weight: nil),
        ])
        let body = try json(data)
        let list = try steps(body)
        #expect((body["sportType"] as? [String: Any])?["sportTypeKey"] as? String == "strength_training")
        #expect(list.count == 2)
        #expect(list[0]["numberOfIterations"] as? Int == 4)
        let squat = try #require(list[0]["workoutSteps"] as? [[String: Any]])
        #expect(squat[0]["category"] as? String == "SQUAT")
        #expect(squat[0]["exerciseName"] as? String == "BARBELL_BACK_SQUAT")
        #expect((squat[0]["endCondition"] as? [String: Any])?["conditionTypeKey"] as? String == "reps")
        #expect(squat[0]["weightValue"] as? Double == 62)
        #expect(squat[1]["endConditionValue"] as? Double == 150)
        let plank = try #require(list[1]["workoutSteps"] as? [[String: Any]])
        #expect(plank[0]["exerciseName"] == nil)
        #expect((plank[0]["endCondition"] as? [String: Any])?["conditionTypeKey"] as? String == "time")
        #expect(plank[0]["description"] as? String == "Prancha lateral - cada lado")
    }

    @Test func descriptionDropsAccents() {
        #expect(GarminPlannedPayload.plain("Agachamento búlgaro · pássaro-cão") == "Agachamento bulgaro · passaro-cao")
    }

    @Test func createScheduleAndDelete() async throws {
        let stub = StubTransport([.ok(#"{"workoutId": 55}"#), .ok("{}"), .ok("")])
        let client = GarminAccountClient(transport: stub, store: PlannedStore())
        let id = try await GarminPlannedUpload.create(client: client, body: Data("{}".utf8), day: Day(iso: "2026-11-19")!)
        try await GarminPlannedUpload.delete(client: client, workoutId: id)
        #expect(id == 55)
        #expect(stub.requests.map { $0.httpMethod ?? "" } == ["POST", "POST", "DELETE"])
        #expect(stub.requests.map { $0.url?.path ?? "" } == ["/workout-service/workout", "/workout-service/schedule/55", "/workout-service/workout/55"])
    }

    @Test func deletesTheCreatedWorkoutWhenSchedulingFails() async throws {
        let stub = StubTransport([.ok(#"{"workoutId": 77}"#), .status(500, "{}"), .ok("")])
        let client = GarminAccountClient(transport: stub, store: PlannedStore())
        await #expect(throws: GarminAccountError.unexpectedResponse(status: 500)) {
            _ = try await GarminPlannedUpload.create(client: client, body: Data("{}".utf8), day: Day(iso: "2026-11-19")!)
        }
        #expect(stub.requests.map { $0.httpMethod ?? "" } == ["POST", "POST", "DELETE"])
        #expect(stub.requests.last?.url?.path == "/workout-service/workout/77")
    }

    @Test func deleteTreatsMissingWorkoutAsDone() async throws {
        let stub = StubTransport([.status(404, "{}")])
        let client = GarminAccountClient(transport: stub, store: PlannedStore())
        try await GarminPlannedUpload.delete(client: client, workoutId: 5)
    }

    @Test func deleteFailsOnOtherErrors() async {
        let stub = StubTransport([.status(500, "{}")])
        let client = GarminAccountClient(transport: stub, store: PlannedStore())
        await #expect(throws: GarminAccountError.unexpectedResponse(status: 500)) {
            try await GarminPlannedUpload.delete(client: client, workoutId: 5)
        }
    }

    @Test func unschedulesOnlyStrengthOnThatDayNotCreatedByTheApp() async throws {
        let calendar = #"{"calendarItems": [{"id": 900, "itemType": "workout", "date": "2026-11-25", "workoutId": 1, "sportTypeKey": "strength_training"}, {"id": 901, "itemType": "workout", "date": "2026-11-25", "workoutId": 2, "sportTypeKey": "running"}, {"id": 902, "itemType": "workout", "date": "2026-11-26", "workoutId": 3, "sportTypeKey": "strength_training"}, {"id": 903, "itemType": "workout", "date": "2026-11-25", "workoutId": 4, "sportTypeKey": "strength_training"}]}"#
        let stub = StubTransport([.ok(calendar), .ok("")])
        let client = GarminAccountClient(transport: stub, store: PlannedStore())
        let removed = try await GarminPlannedUpload.unscheduleStrength(client: client, on: Day(iso: "2026-11-25")!, keeping: [4])
        #expect(removed == 1)
        #expect(stub.requests.map { $0.httpMethod ?? "" } == ["GET", "DELETE"])
        #expect(stub.requests.last?.url?.path == "/workout-service/schedule/900")
        #expect(stub.requests.first?.url?.path == "/calendar-service/year/2026/month/10")
    }
}
