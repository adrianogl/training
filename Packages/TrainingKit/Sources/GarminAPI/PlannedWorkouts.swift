import Foundation
import TrainingCore

public enum PlannedWorkouts {
    static let runSport = "running"
    static let workoutItem = "workout"
    static let repeatType = "RepeatGroupDTO"
    static let timeCondition = "time"
    static let distanceCondition = "distance"
    static let paceTarget = "pace.zone"
    static let heartRateTarget = "heart.rate.zone"
    static let metersPerKilometer = 1_000.0
    static let defaultPaces: [PlannedStepKind: Double] = [
        .warmup: 360, .active: 300, .recovery: 390, .cooldown: 375, .rest: 0, .other: 345,
    ]
    static let kinds: [String: PlannedStepKind] = [
        "warmup": .warmup, "interval": .active, "recovery": .recovery, "cooldown": .cooldown, "rest": .rest,
    ]

    public static func fetch(client: GarminAccountClient, from first: Day, through last: Day) async throws -> [PlannedWorkout] {
        var months: [(Int, Int)] = []
        for day in [first, last] where !months.contains(where: { $0 == (day.year, day.month) }) {
            months.append((day.year, day.month))
        }
        var items: [CalendarDTO.Item] = []
        for (year, month) in months {
            let path = String(format: GarminAccountEndpoints.calendarPathFormat, year, month - 1)
            items += try JSONDecoder().decode(CalendarDTO.self, from: try await client.get(path)).calendarItems
        }
        let runs = runItems(items, from: first, through: last).compactMap { item in
            item.workoutId.flatMap { id in item.date.map { (id: id, day: $0, title: item.title) } }
        }
        return try await withThrowingTaskGroup(of: (Int, PlannedWorkout).self) { group in
            for (index, run) in runs.enumerated() {
                group.addTask {
                    let data = try await client.get(GarminAccountEndpoints.workoutPathPrefix + String(run.id))
                    return (index, workout(try JSONDecoder().decode(WorkoutDTO.self, from: data), day: run.day, fallbackTitle: run.title))
                }
            }
            var results: [(Int, PlannedWorkout)] = []
            for try await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    static func runItems(_ items: [CalendarDTO.Item], from first: Day, through last: Day) -> [CalendarDTO.Item] {
        var seen = Set<Int64>()
        return items.filter { item in
            guard item.itemType == workoutItem, item.sportTypeKey == runSport,
                  let iso = item.date, let day = Day(iso: iso), first <= day, day <= last,
                  let id = item.workoutId, !seen.contains(id)
            else { return false }
            seen.insert(id)
            return true
        }
    }

    static func workout(_ dto: WorkoutDTO, day: String, fallbackTitle: String?) -> PlannedWorkout {
        let steps = (dto.workoutSegments ?? []).flatMap { ($0.workoutSteps ?? []).map(step) }
        let estimate = estimate(steps.flatMap(\.flattened))
        return PlannedWorkout(
            id: dto.workoutId,
            day: day,
            title: dto.workoutName ?? fallbackTitle ?? "",
            estimatedSeconds: dto.estimatedDurationInSecs ?? estimate?.seconds,
            estimatedMeters: dto.estimatedDistanceInMeters ?? estimate?.meters,
            steps: steps
        )
    }

    static func estimate(_ steps: [PlannedStep]) -> (meters: Double, seconds: Double)? {
        var meters = 0.0
        var seconds = 0.0
        for step in steps {
            let pace = pace(step)
            if let distance = step.meters {
                meters += distance
                seconds += distance / metersPerKilometer * pace
            } else if let time = step.seconds {
                seconds += time
                meters += pace > 0 ? time / pace * metersPerKilometer : 0
            }
        }
        return meters > 0 ? (meters, seconds) : nil
    }

    static func pace(_ step: PlannedStep) -> Double {
        if case .pace(let fastest, let slowest) = step.target { return (fastest + slowest) / 2 }
        return defaultPaces[step.kind] ?? 0
    }

    static func step(_ dto: StepDTO) -> PlannedStep {
        if dto.type == repeatType {
            return PlannedStep(kind: .other, repeats: dto.numberOfIterations ?? 1, children: (dto.workoutSteps ?? []).map(step))
        }
        let condition = dto.endCondition?.conditionTypeKey
        return PlannedStep(
            kind: kinds[dto.stepType?.stepTypeKey ?? ""] ?? .other,
            seconds: condition == timeCondition ? dto.endConditionValue : nil,
            meters: condition == distanceCondition ? dto.endConditionValue : nil,
            target: target(dto)
        )
    }

    static func target(_ dto: StepDTO) -> PlannedTarget? {
        switch dto.targetType?.workoutTargetTypeKey {
        case paceTarget:
            guard let one = dto.targetValueOne, let two = dto.targetValueTwo, one > 0, two > 0 else { return nil }
            let paces = [metersPerKilometer / one, metersPerKilometer / two]
            return .pace(fastest: paces.min()!, slowest: paces.max()!)
        case heartRateTarget:
            if let one = dto.targetValueOne, let two = dto.targetValueTwo { return .heartRate(low: min(one, two), high: max(one, two)) }
            return dto.zoneNumber.map(PlannedTarget.zone)
        default:
            return dto.zoneNumber.map(PlannedTarget.zone)
        }
    }
}
