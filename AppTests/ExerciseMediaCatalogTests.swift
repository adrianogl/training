import Foundation
import Insights
import Testing
@testable import trAIning

@Suite struct ExerciseMediaCatalogTests {
    private static let catalog = ExerciseMediaCatalog.shared

    @Test func goblet_lists_photos_then_wger_then_drawing() {
        let items = Self.catalog.media(for: .catalog("SQUAT/GOBLET_SQUAT"), fallback: nil)
        let sources = items.map(\.source)
        #expect(sources.first == .freeExerciseDb)
        #expect(sources.last == .drawing)
        #expect(sources.filter { $0 == .wger }.count == 3)
        #expect(sources.firstIndex(of: .wger)! > sources.firstIndex(of: .freeExerciseDb)!)
        #expect(items.first?.frames.count == 2)
        #expect(items.first?.id == "freeExerciseDb:Goblet_Squat_0.jpg")
        #expect(items.filter { $0.source == .wger }.allSatisfy { $0.frames.count == 1 && $0.steps.isEmpty })
        #expect(items.last?.id == "drawing:squat")
        #expect(items.last?.pattern == .squat)
        #expect(items.last?.steps.isEmpty == false)
    }

    @Test func unknown_id_returns_only_drawing() {
        let items = Self.catalog.media(for: .catalog("NAO/EXISTE"), fallback: .hinge)
        #expect(items.count == 1)
        #expect(items.first?.id == "drawing:hinge")
    }

    @Test func unknown_id_without_fallback_returns_nothing() {
        #expect(Self.catalog.media(for: .catalog("NAO/EXISTE"), fallback: nil).isEmpty)
    }

    @Test func mfit_name_with_accent_and_spaces_maps_to_catalog() {
        let key = Self.catalog.key(forMFITName: "  Agachamento   Búlgaro ", category: "SQUAT")
        #expect(key == .catalog("LUNGE/DUMBBELL_OVERHEAD_BULGARIAN_SPLIT_SQUAT"))
    }

    @Test func mfit_unknown_name_uses_category_pattern_drawing() {
        let key = Self.catalog.key(forMFITName: "Exercicio Inventado Xyz", category: "SQUAT")
        #expect(key == .mfit("SQUAT"))
        let items = Self.catalog.media(for: key, fallback: nil)
        #expect(items.map(\.id) == ["drawing:squat"])
    }

    @Test func alternatives_respect_pattern_and_limit_3() {
        let own = StrengthCatalog.exercise("SQUAT/GOBLET_SQUAT")
        let alternatives = Self.catalog.alternatives(for: .catalog("SQUAT/GOBLET_SQUAT"), source: .freeExerciseDb, excluding: [], limit: 3)
        #expect(alternatives.count == 3)
        #expect(alternatives.allSatisfy { $0.source == .freeExerciseDb })
        let ownIds = Set(Self.catalog.media(for: .catalog(own!.id), fallback: nil).map(\.id))
        #expect(alternatives.allSatisfy { !ownIds.contains($0.id) })
        let excluded = Set(alternatives.map(\.id))
        let next = Self.catalog.alternatives(for: .catalog("SQUAT/GOBLET_SQUAT"), source: .freeExerciseDb, excluding: excluded, limit: 3)
        #expect(excluded.isDisjoint(with: next.map(\.id)))
    }
}
