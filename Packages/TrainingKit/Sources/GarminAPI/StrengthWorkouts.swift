import Foundation
import TrainingCore

public enum StrengthWorkouts {
    public static let sport = "strength_training"
    static let restKey = "rest"
    static let timeCondition = "time"
    static let repsCondition = "reps"
    static let detailSeparator = " - "

    public static func fetch(client: GarminAccountClient, from first: Day, through last: Day) async throws -> [StrengthWorkout] {
        var months: [(Int, Int)] = []
        for day in [first, last] where !months.contains(where: { $0 == (day.year, day.month) }) {
            months.append((day.year, day.month))
        }
        let items = try await PlannedWorkouts.calendarItems(client: client, months: months)
        let planned = PlannedWorkouts.workoutItems(items, sport: sport, from: first, through: last).compactMap { item in
            item.workoutId.flatMap { id in item.date.map { (id: id, day: $0, title: item.title) } }
        }
        return try await withThrowingTaskGroup(of: (Int, StrengthWorkout).self) { group in
            for (index, entry) in planned.enumerated() {
                group.addTask {
                    let data = try await client.get(GarminAccountEndpoints.workoutPathPrefix + String(entry.id))
                    return (index, workout(try JSONDecoder().decode(WorkoutDTO.self, from: data), day: entry.day, fallbackTitle: entry.title))
                }
            }
            var results: [(Int, StrengthWorkout)] = []
            for try await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }

    static func workout(_ dto: WorkoutDTO, day: String, fallbackTitle: String?) -> StrengthWorkout {
        let steps = (dto.workoutSegments ?? []).flatMap { $0.workoutSteps ?? [] }
        return StrengthWorkout(id: dto.workoutId, day: day, title: dto.workoutName ?? fallbackTitle ?? "", blocks: steps.compactMap(block))
    }

    static func block(_ dto: StepDTO) -> StrengthBlock? {
        let children = dto.type == PlannedWorkouts.repeatType ? (dto.workoutSteps ?? []) : [dto]
        let exercises = children.filter { !isRest($0) }.map(exercise)
        guard !exercises.isEmpty else { return nil }
        let rest = children.first(where: isRest)?.endConditionValue
        let sets = dto.type == PlannedWorkouts.repeatType ? max(dto.numberOfIterations ?? 1, 1) : 1
        return StrengthBlock(exercises: exercises, sets: sets, restSeconds: rest)
    }

    static func isRest(_ dto: StepDTO) -> Bool {
        dto.stepType?.stepTypeKey == restKey
    }

    static func exercise(_ dto: StepDTO) -> StrengthExercise {
        let condition = dto.endCondition?.conditionTypeKey
        let reps = condition == repsCondition ? dto.endConditionValue.map { Int($0) } : nil
        let seconds = condition == timeCondition ? dto.endConditionValue : nil
        let parts = (dto.description ?? "").components(separatedBy: detailSeparator)
        let written = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        let writtenDetail = parts.count > 1 ? parts.dropFirst().joined(separator: detailSeparator).trimmingCharacters(in: .whitespaces) : nil
        let name = written.isEmpty ? keyName(dto.exerciseName ?? dto.category) : written
        let detail = writtenDetail ?? reps.map { "\($0) rep" } ?? seconds.map { "\(Int($0)) s" }
        return StrengthExercise(name: name, detail: detail, category: dto.category, exerciseKey: dto.exerciseName, reps: reps, seconds: seconds)
    }

    public static func displayName(_ key: String?) -> String {
        keyName(key)
    }

    static func keyName(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "" }
        return key.split(separator: "_").joined(separator: " ").lowercased().capitalizedFirst
    }
}

public enum ExerciseSets {
    static let activeType = "ACTIVE"
    static let gramsPerKilogram = 1_000.0

    public static func fetch(client: GarminAccountClient, activityId: Int64) async throws -> [StrengthSet] {
        try parse(try await client.get(String(format: GarminAccountEndpoints.exerciseSetsPathFormat, activityId)))
    }

    static func parse(_ data: Data) throws -> [StrengthSet] {
        let dto = try JSONDecoder().decode(ExerciseSetsDTO.self, from: data)
        return (dto.exerciseSets ?? []).filter { $0.setType == activeType }.map { set in
            let exercise = set.exercises?.first
            return StrengthSet(
                stepIndex: set.wktStepIndex,
                category: exercise?.category,
                exerciseKey: exercise?.name,
                reps: set.repetitionCount,
                seconds: set.duration,
                weight: set.weight.map { $0 / gramsPerKilogram }
            )
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
