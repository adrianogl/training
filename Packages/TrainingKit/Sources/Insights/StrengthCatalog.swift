import Foundation

public enum StrengthCatalog {
    public static let all: [CatalogExercise] = StrengthCatalogLoader.decode(GarminStrengthCatalogData.json)

    private static let byId: [String: CatalogExercise] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    public static let garminCategories: Set<String> = Set(all.map(\.category))

    public static func garminCategory(_ category: String) -> String {
        let key = category.uppercased()
        let mapped = StrengthCatalogConstants.garminCategoryAliases[key] ?? key
        return garminCategories.contains(mapped) ? mapped : StrengthCatalogConstants.fallbackGarminCategory
    }

    public static func exercise(_ id: String) -> CatalogExercise? {
        byId[canonicalId(id)]
    }

    public static func canonicalId(_ id: String) -> String {
        StrengthCatalogConstants.legacyIds[id] ?? id
    }

    public static func names(of exercise: CatalogExercise) -> [String] {
        [exercise.name] + (StrengthCatalogConstants.legacyNames[exercise.id].map { [$0] } ?? [])
    }

    public static func contextLine(_ exercise: CatalogExercise) -> String {
        let marks = (exercise.unilateral ? "u" : "") + (exercise.timed ? "i" : "")
        return [
            exercise.id, exercise.pattern.rawValue, exercise.equipment.rawValue,
            exercise.loads.map(\.rawValue).sorted().joined(separator: ","), exercise.focus.map(\.rawValue).sorted().joined(separator: ","), marks,
        ].joined(separator: "|")
    }

    public static func pattern(garminCategory: String) -> MovementPattern? {
        StrengthCatalogConstants.patternByGarminCategory[garminCategory.uppercased()]
    }
}
