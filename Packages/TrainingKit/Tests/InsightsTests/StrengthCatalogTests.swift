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

    @Test func everyExerciseIsAnOfficialGarminExercise() {
        #expect(StrengthCatalog.all.count > 1000)
        for exercise in StrengthCatalog.all {
            #expect(!exercise.exerciseName.isEmpty, "\(exercise.id)")
            #expect(exercise.id == "\(exercise.category)/\(exercise.exerciseName)")
        }
    }

    @Test func cardioAndSpecialEquipmentCategoriesAreLeftOut() {
        let categories = Set(StrengthCatalog.all.map(\.category))
        for excluded in ["RUN", "INDOOR_BIKE", "CARDIO", "SLED", "TIRE", "SANDBAG", "OLYMPIC_LIFT", "BATTLE_ROPE"] {
            #expect(!categories.contains(excluded), "\(excluded)")
        }
    }

    @Test func newEquipmentOnlyCountsAtTheGym() {
        for equipment in [StrengthEquipment.kettlebell, .medicineBall, .suspension, .swissBall] {
            let exercise = StrengthCatalog.all.first { $0.equipment == equipment }
            #expect(exercise?.fits(.gym) == true)
            #expect(exercise?.fits(.home) == false)
            #expect(exercise?.fits(.bodyweight) == false)
        }
    }

    @Test func legacyIdsPointToCatalogExercises() {
        for (old, new) in StrengthCatalogConstants.legacyIds {
            #expect(StrengthCatalog.exercise(old)?.id == new, "\(old)")
        }
        #expect(StrengthCatalogConstants.legacyIds.count == 61)
        #expect(StrengthCatalogConstants.legacyNames.count == 61)
        #expect(StrengthCatalog.names(of: StrengthCatalog.exercise("agachamento-livre")!) == ["Agachamento com barra nas costas", "Agachamento livre"])
    }

    @Test func painRegionsFollowTheMovement() {
        #expect(StrengthCatalog.exercise("SQUAT/GOBLET_SQUAT")?.loads.contains(.knee) == true)
        #expect(StrengthCatalog.exercise("DEADLIFT/ROMANIAN_DEADLIFT")?.loads.contains(.lowerBack) == true)
        #expect(StrengthCatalog.exercise("PLYO/BOX_JUMP")?.loads.isSuperset(of: [.knee, .calfAchilles]) == true)
        #expect(StrengthCatalog.exercise("SHOULDER_PRESS/DUMBBELL_SHOULDER_PRESS")?.loads.contains(.shoulder) == true)
        #expect(StrengthCatalog.exercise("PLYO/MEDICINE_BALL_SLAM")?.loads.contains(.knee) == false)
    }

    @Test func mapsGarminCategoriesToPatterns() {
        #expect(StrengthCatalog.pattern(garminCategory: "SQUAT") == .squat)
        #expect(StrengthCatalog.pattern(garminCategory: "calf_raise") == .calf)
        #expect(StrengthCatalog.pattern(garminCategory: "UNKNOWN") == nil)
    }
}
