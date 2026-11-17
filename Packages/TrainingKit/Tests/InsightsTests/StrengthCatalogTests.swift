import Testing
@testable import Insights

@Suite struct StrengthCatalogTests {
    @Test func everyExerciseHasAGarminCategoryAndAName() {
        for exercise in StrengthCatalog.all {
            #expect(!exercise.category.isEmpty, "\(exercise.id)")
            #expect(!exercise.name.isEmpty, "\(exercise.id)")
        }
    }

    @Test func idsAreUnique() {
        let ids = StrengthCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyFocusHasExercisesInEveryPlace() {
        for group in TrainerStrengthGroup.allCases {
            for place in StrengthPlace.allCases {
                let available = StrengthCatalog.all.filter { $0.focus.contains(group) && $0.fits(place) }
                #expect(available.count >= 6, "\(group) \(place) tem \(available.count)")
            }
        }
    }

    @Test func runnerPatternsAreCovered() {
        let patterns = Set(StrengthCatalog.all.map(\.pattern))
        for pattern in [MovementPattern.calf, .hipStability, .antiRotation, .singleLeg, .mobilityHip, .mobilityAnkle] {
            #expect(patterns.contains(pattern), "\(pattern)")
        }
    }

    @Test func bodyweightOnlyNeedsNoEquipment() {
        let bodyweight = StrengthCatalog.all.filter { $0.fits(.bodyweight) }
        #expect(bodyweight.allSatisfy { $0.equipment == .bodyweight })
    }

    @Test func mapsGarminCategoriesToPatterns() {
        #expect(StrengthCatalog.pattern(garminCategory: "SQUAT") == .squat)
        #expect(StrengthCatalog.pattern(garminCategory: "calf_raise") == .calf)
        #expect(StrengthCatalog.pattern(garminCategory: "UNKNOWN") == nil)
    }
}
