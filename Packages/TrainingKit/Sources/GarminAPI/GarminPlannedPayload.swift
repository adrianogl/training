import Foundation
import TrainingCore

public enum GarminPlannedPayload {
    static var running: [String: Any] { ["sportTypeId": 1, "sportTypeKey": "running"] }
    static var strength: [String: Any] { ["sportTypeId": 5, "sportTypeKey": "strength_training"] }
    static var noTarget: [String: Any] { ["workoutTargetTypeId": 1, "workoutTargetTypeKey": "no.target"] }
    static var paceTarget: [String: Any] { ["workoutTargetTypeId": 6, "workoutTargetTypeKey": "pace.zone"] }
    static var distance: [String: Any] { ["conditionTypeId": 3, "conditionTypeKey": "distance"] }
    static var time: [String: Any] { ["conditionTypeId": 2, "conditionTypeKey": "time"] }
    static var reps: [String: Any] { ["conditionTypeId": 10, "conditionTypeKey": "reps"] }
    static var iterations: [String: Any] { ["conditionTypeId": 7, "conditionTypeKey": "iterations"] }
    static let stepTypes: [String: Int] = ["warmup": 1, "cooldown": 2, "interval": 3, "recovery": 4, "rest": 5, "repeat": 6]
    static let metersPerKilometer = 1_000.0

    public static func running(name: String, steps: [PlannedRunStep]) throws -> Data {
        var order = 0
        let list = steps.map { runStep($0, order: &order) }
        return try body(name: name, sport: running, steps: list)
    }

    public static func strength(name: String, exercises: [PlannedStrengthExercise]) throws -> Data {
        var order = 0
        let list: [[String: Any]] = exercises.map { exercise in
            order += 1
            let groupOrder = order
            order += 1
            var work: [String: Any] = executable("interval", order: order)
            work["description"] = plain(exercise.description)
            work["category"] = exercise.category
            if let name = exercise.exerciseName { work["exerciseName"] = name }
            if let seconds = exercise.seconds {
                work["endCondition"] = time
                work["endConditionValue"] = Double(seconds)
            } else {
                work["endCondition"] = reps
                work["endConditionValue"] = Double(exercise.reps ?? 0)
            }
            if let weight = exercise.weight {
                work["weightValue"] = weight
                work["weightUnit"] = ["unitKey": "kilogram"]
            }
            order += 1
            var rest = executable("rest", order: order)
            rest["endCondition"] = time
            rest["endConditionValue"] = Double(exercise.restSeconds)
            return repeatGroup(times: exercise.sets, order: groupOrder, steps: [work, rest])
        }
        return try body(name: name, sport: strength, steps: list)
    }

    public static func plain(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
    }

    private static func runStep(_ step: PlannedRunStep, order: inout Int) -> [String: Any] {
        order += 1
        switch step {
        case .warmup(let meters): return distanceStep("warmup", meters: meters, order: order)
        case .cooldown(let meters): return distanceStep("cooldown", meters: meters, order: order)
        case .recovery(let meters): return distanceStep("recovery", meters: meters, order: order)
        case .rest(let seconds):
            var rest = executable("rest", order: order)
            rest["endCondition"] = time
            rest["endConditionValue"] = seconds
            return rest
        case .interval(let meters, let fastest, let slowest):
            var interval = distanceStep("interval", meters: meters, order: order)
            if let fastest, let slowest, fastest > 0, slowest > 0 {
                interval["targetType"] = paceTarget
                interval["targetValueOne"] = metersPerKilometer / max(fastest, slowest)
                interval["targetValueTwo"] = metersPerKilometer / min(fastest, slowest)
            }
            return interval
        case .repeated(let times, let inner):
            let groupOrder = order
            let children = inner.map { runStep($0, order: &order) }
            return repeatGroup(times: times, order: groupOrder, steps: children)
        }
    }

    private static func distanceStep(_ kind: String, meters: Double, order: Int) -> [String: Any] {
        var step = executable(kind, order: order)
        step["endCondition"] = distance
        step["endConditionValue"] = meters
        return step
    }

    private static func executable(_ kind: String, order: Int) -> [String: Any] {
        [
            "type": "ExecutableStepDTO",
            "stepOrder": order,
            "stepType": ["stepTypeId": stepTypes[kind] ?? 3, "stepTypeKey": kind],
            "targetType": noTarget,
        ]
    }

    private static func repeatGroup(times: Int, order: Int, steps: [[String: Any]]) -> [String: Any] {
        [
            "type": "RepeatGroupDTO",
            "stepOrder": order,
            "stepType": ["stepTypeId": stepTypes["repeat"] ?? 6, "stepTypeKey": "repeat"],
            "numberOfIterations": times,
            "smartRepeat": false,
            "endCondition": iterations,
            "endConditionValue": Double(times),
            "workoutSteps": steps,
        ]
    }

    private static func body(name: String, sport: [String: Any], steps: [[String: Any]]) throws -> Data {
        let body: [String: Any] = [
            "workoutName": name,
            "sportType": sport,
            "workoutSegments": [["segmentOrder": 1, "sportType": sport, "workoutSteps": steps]],
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }
}

public enum GarminPlannedUpload {
    public static func create(client: GarminAccountClient, body: Data, day: Day) async throws -> Int64 {
        let created = try JSONDecoder().decode(GarminWorkoutUpload.Created.self, from: try await client.post(GarminAccountEndpoints.createWorkoutPath, body: body))
        let schedule = try JSONSerialization.data(withJSONObject: ["date": day.iso])
        do {
            _ = try await client.post(GarminAccountEndpoints.schedulePathPrefix + String(created.workoutId), body: schedule)
        } catch {
            try? await delete(client: client, workoutId: created.workoutId)
            throw error
        }
        return created.workoutId
    }

    @discardableResult
    public static func unscheduleStrength(client: GarminAccountClient, on day: Day, keeping created: Set<Int64>) async throws -> Int {
        let path = String(format: GarminAccountEndpoints.calendarPathFormat, day.year, day.month - 1)
        let items = try JSONDecoder().decode(CalendarDTO.self, from: try await client.get(path)).calendarItems
        let scheduled = items.filter { item in
            item.itemType == PlannedWorkouts.workoutItem && item.sportTypeKey == strengthSport && item.date == day.iso
                && item.id != nil && !(item.workoutId.map(created.contains) ?? false)
        }
        for item in scheduled {
            guard let id = item.id else { continue }
            _ = try await client.delete(GarminAccountEndpoints.schedulePathPrefix + String(id))
        }
        return scheduled.count
    }

    static let strengthSport = "strength_training"

    public static func delete(client: GarminAccountClient, workoutId: Int64) async throws {
        do {
            _ = try await client.delete(GarminAccountEndpoints.workoutPathPrefix + String(workoutId))
        } catch GarminAccountError.unexpectedResponse(status: notFound) {
            return
        }
    }

    static let notFound = 404
}
