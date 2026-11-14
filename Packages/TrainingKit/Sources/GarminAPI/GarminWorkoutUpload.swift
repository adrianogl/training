import Foundation
import TrainingCore

public struct UploadStep: Sendable, Equatable {
    public let meters: Double
    public let fastestSecondsPerKm: Double
    public let slowestSecondsPerKm: Double

    public init(meters: Double, fastestSecondsPerKm: Double, slowestSecondsPerKm: Double) {
        self.meters = meters
        self.fastestSecondsPerKm = fastestSecondsPerKm
        self.slowestSecondsPerKm = slowestSecondsPerKm
    }
}

public enum GarminWorkoutUpload {
    struct Created: Decodable {
        let workoutId: Int64
    }

    static let metersPerKilometer = 1_000.0

    public static func payload(name: String, steps: [UploadStep]) throws -> Data {
        let running: [String: Any] = ["sportTypeId": 1, "sportTypeKey": "running"]
        let workoutSteps: [[String: Any]] = steps.enumerated().map { index, step in
            [
                "type": "ExecutableStepDTO",
                "stepOrder": index + 1,
                "stepType": ["stepTypeId": 3, "stepTypeKey": "interval"],
                "endCondition": ["conditionTypeId": 3, "conditionTypeKey": "distance"],
                "endConditionValue": step.meters,
                "targetType": ["workoutTargetTypeId": 6, "workoutTargetTypeKey": "pace.zone"],
                "targetValueOne": metersPerKilometer / step.slowestSecondsPerKm,
                "targetValueTwo": metersPerKilometer / step.fastestSecondsPerKm,
            ]
        }
        let body: [String: Any] = [
            "workoutName": name,
            "sportType": running,
            "workoutSegments": [["segmentOrder": 1, "sportType": running, "workoutSteps": workoutSteps]],
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    public static func upload(client: GarminAccountClient, name: String, steps: [UploadStep], day: Day) async throws -> Int64 {
        let created = try JSONDecoder().decode(Created.self, from: try await client.post(GarminAccountEndpoints.createWorkoutPath, body: payload(name: name, steps: steps)))
        let schedule = try JSONSerialization.data(withJSONObject: ["date": day.iso])
        _ = try await client.post(GarminAccountEndpoints.schedulePathPrefix + String(created.workoutId), body: schedule)
        return created.workoutId
    }
}
