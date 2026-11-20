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

    @Test func json_order_own_equivalent_wger_then_drawing() {
        let items = Self.catalog.media(for: .catalog("BENCH_PRESS/BENCH_PRESS"), fallback: nil)
        let order = items.map { item -> Int in
            switch (item.source, item.equivalent) {
            case (.freeExerciseDb, false): 0
            case (.freeExerciseDb, true): 1
            case (.wger, _): 2
            case (.drawing, _): 3
            }
        }
        #expect(order == order.sorted())
        #expect(Set(order) == [0, 1, 2, 3])
        #expect(items.filter { $0.source == .drawing }.count == 1)
    }

    @Test func mapped_mfit_name_returns_catalog_photos() {
        let key = Self.catalog.key(forMFITName: " Agachamento   GOBLET ", category: "SQUAT")
        #expect(key == .catalog("SQUAT/GOBLET_SQUAT"))
        let items = Self.catalog.media(for: key, fallback: nil)
        #expect(items.first?.id == "freeExerciseDb:Goblet_Squat_0.jpg")
        #expect(items.last?.source == .drawing)
    }

    @Test func mfit_name_with_accent_and_spaces_maps_to_catalog() {
        let key = Self.catalog.key(forMFITName: "  Afundo   Lateral ", category: "LUNGE")
        #expect(key == .catalog("LUNGE/SIDE_LUNGE"))
        if case .catalog(let id) = key { #expect(!id.contains("SHIFTING") && !id.contains("OVERHEAD")) }
    }

    @Test func mfit_unknown_name_uses_category_pattern_drawing() {
        let key = Self.catalog.key(forMFITName: "  Exercício   Inventado Xyz", category: "SQUAT")
        #expect(key == .mfit("exercicio inventado xyz"))
        let items = Self.catalog.media(for: key, fallback: StrengthCatalog.pattern(garminCategory: "SQUAT"))
        #expect(items.map(\.id) == ["drawing:squat"])
        #expect(Self.catalog.media(for: key, fallback: nil).isEmpty)
    }

    @Test func alternatives_respect_pattern_and_limit_3() {
        let alternatives = Self.catalog.alternatives(for: .catalog("SQUAT/GOBLET_SQUAT"), source: .freeExerciseDb, excluding: [], limit: 3, fallback: nil)
        #expect(alternatives.count == 3)
        #expect(alternatives.allSatisfy { $0.source == .freeExerciseDb })
        let ownIds = Set(Self.catalog.media(for: .catalog("SQUAT/GOBLET_SQUAT"), fallback: nil).map(\.id))
        #expect(alternatives.allSatisfy { !ownIds.contains($0.id) })
        let excluded = Set(alternatives.map(\.id))
        let next = Self.catalog.alternatives(for: .catalog("SQUAT/GOBLET_SQUAT"), source: .freeExerciseDb, excluding: excluded, limit: 3, fallback: nil)
        #expect(excluded.isDisjoint(with: next.map(\.id)))
    }

    @Test func mfit_alternatives_use_fallback_pattern() {
        let key = ExerciseKey.mfit("exercicio inventado xyz")
        #expect(Self.catalog.alternatives(for: key, source: .freeExerciseDb, excluding: [], limit: 3, fallback: nil).isEmpty)
        #expect(Self.catalog.alternatives(for: key, source: .freeExerciseDb, excluding: [], limit: 3, fallback: .squat).count == 3)
    }

    @Test func alternatives_rank_by_equipment_then_tokens() throws {
        let ownId = "SQUAT/GOBLET_SQUAT"
        let own = try #require(StrengthCatalog.exercise(ownId))
        let ids = StrengthCatalog.all.filter { $0.pattern == own.pattern && $0.id != ownId }.prefix(40).map(\.id)
        let midias = ids.enumerated().map { index, id in
            "\"\(id)\":[{\"origem\":\"freeExerciseDb\",\"quadros\":[\"f\(index)_0.jpg\",\"f\(index)_1.jpg\"],\"equivalente\":false}]"
        }.joined(separator: ",")
        let json = "{\"versao\":1,\"midias\":{\(midias)},\"mfit\":{},\"padroes\":{}}"
        let synthetic = ExerciseMediaCatalog(data: Data(json.utf8))
        let result = synthetic.alternatives(for: .catalog(ownId), source: .freeExerciseDb, excluding: [], limit: 40, fallback: nil)
        #expect(result.count == ids.count)
        let ownTokens = Set(own.name.lowercased().split(separator: " ").map(String.init).filter { $0.count > 2 })
        let scores: [(Bool, Int)] = result.map { media in
            let index = Int(media.frames[0].dropFirst().prefix(while: { $0 != "_" }))!
            let candidate = StrengthCatalog.exercise(ids[index])!
            let tokens = Set(candidate.name.lowercased().split(separator: " ").map(String.init).filter { $0.count > 2 })
            return (candidate.equipment == own.equipment, ownTokens.intersection(tokens).count)
        }
        #expect(scores.contains { $0.0 } && scores.contains { !$0.0 })
        for (left, right) in zip(scores, scores.dropFirst()) {
            #expect(left.0 || !right.0)
            if left.0 == right.0 { #expect(left.1 >= right.1) }
        }
    }
}
