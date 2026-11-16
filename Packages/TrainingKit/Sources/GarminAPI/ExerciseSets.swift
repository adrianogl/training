import Foundation

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
                category: exercise?.category,
                exerciseKey: exercise?.name,
                reps: set.repetitionCount,
                weight: set.weight.flatMap { $0 > 0 ? $0 / gramsPerKilogram : nil }
            )
        }
    }
}
