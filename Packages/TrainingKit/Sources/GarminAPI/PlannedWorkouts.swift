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
        let runs = runItems(items, from: first, through: last)
        var workouts: [PlannedWorkout] = []
        for item in runs {
            guard let id = item.workoutId, let day = item.date else { continue }
            let data = try await client.get(GarminAccountEndpoints.workoutPathPrefix + String(id))
            workouts.append(workout(try JSONDecoder().decode(WorkoutDTO.self, from: data), day: day, fallbackTitle: item.title))
        }
        return workouts
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
        PlannedWorkout(
            id: dto.workoutId,
            day: day,
            title: dto.workoutName ?? fallbackTitle ?? "",
            estimatedSeconds: dto.estimatedDurationInSecs,
            estimatedMeters: dto.estimatedDistanceInMeters,
            steps: (dto.workoutSegments ?? []).flatMap { ($0.workoutSteps ?? []).map(step) }
        )
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
