import Testing
import TrainingCore
@testable import Insights

@Suite struct StrengthLoadSuggestionTests {
    private func exercise(_ id: String) -> CatalogExercise {
        StrengthCatalog.exercise(id)!
    }

    private func record(_ weight: Double, day: String? = "2026-11-10") -> StrengthLoadRecord {
        StrengthLoadRecord(weight: weight, completedAllSets: true, day: day)
    }

    @Test func hinge_pattern_unilateral_dumbbell_target_halves_the_discounted_base() {
        let suggestion = StrengthLoadSuggestion.suggest(for: exercise("HIP_RAISE/WEIGHTED_SINGLE_LEG_HIP_RAISE"), history: ["DEADLIFT/ROMANIAN_DEADLIFT": record(40)])
        #expect(suggestion?.weight == 8)
        #expect(suggestion?.baseId == "DEADLIFT/ROMANIAN_DEADLIFT")
        #expect(suggestion?.baseWeight == 40)
        #expect(suggestion?.baseDay == "2026-11-10")
    }

    @Test func rdl_barbell_40_to_single_leg_rdl_dumbbell_is_8() {
        let suggestion = StrengthLoadSuggestion.suggest(for: exercise("DEADLIFT/SINGLE_LEG_ROMANIAN_DEADLIFT_WITH_DUMBBELL"), history: ["DEADLIFT/ROMANIAN_DEADLIFT": record(40)])
        #expect(suggestion?.weight == 8)
        #expect(suggestion?.baseId == "DEADLIFT/ROMANIAN_DEADLIFT")
        #expect(suggestion?.baseWeight == 40)
    }

    @Test func unilateral_base_never_suggests_bilateral_across_category() {
        #expect(StrengthLoadSuggestion.suggest(for: exercise("DEADLIFT/ROMANIAN_DEADLIFT"), history: ["DEADLIFT/SINGLE_LEG_ROMANIAN_DEADLIFT_WITH_DUMBBELL": record(10)]) == nil)
    }

    @Test func same_equipment_bilateral_discount_only() {
        let suggestion = StrengthLoadSuggestion.suggest(for: exercise("SQUAT/DUMBBELL_FRONT_SQUAT"), history: ["SQUAT/GOBLET_SQUAT": record(16)])
        #expect(suggestion?.weight == 12)
    }

    @Test func rounds_down_to_increment() {
        let suggestion = StrengthLoadSuggestion.suggest(for: exercise("SQUAT/BARBELL_FRONT_SQUAT"), history: ["SQUAT/BARBELL_BACK_SQUAT": record(87)])
        #expect(suggestion?.weight == 67.5)
    }

    @Test func below_one_increment_returns_nil() {
        #expect(StrengthLoadSuggestion.suggest(for: exercise("HIP_RAISE/WEIGHTED_SINGLE_LEG_HIP_RAISE"), history: ["DEADLIFT/ROMANIAN_DEADLIFT": record(2)]) == nil)
    }

    @Test func bodyweight_never_suggests() {
        #expect(StrengthLoadSuggestion.suggest(for: exercise("SQUAT/AIR_SQUAT"), history: ["SQUAT/BARBELL_BACK_SQUAT": record(80)]) == nil)
    }

    @Test func no_same_pattern_history_returns_nil() {
        #expect(StrengthLoadSuggestion.suggest(for: exercise("SQUAT/DUMBBELL_FRONT_SQUAT"), history: ["DEADLIFT/ROMANIAN_DEADLIFT": record(60)]) == nil)
        #expect(StrengthLoadSuggestion.suggest(for: exercise("SQUAT/DUMBBELL_FRONT_SQUAT"), history: [:]) == nil)
    }

    @Test func same_equipment_wins_over_barbell_pair() {
        let history = ["SQUAT/BARBELL_BACK_SQUAT": record(100, day: "2026-11-15"), "SQUAT/GOBLET_SQUAT": record(16, day: "2026-11-01")]
        #expect(StrengthLoadSuggestion.suggest(for: exercise("SQUAT/DUMBBELL_FRONT_SQUAT"), history: history)?.baseId == "SQUAT/GOBLET_SQUAT")
    }

    @Test func most_recent_base_wins_and_ties_are_alphabetical() {
        let recent = ["SQUAT/GOBLET_SQUAT": record(16, day: "2026-11-01"), "SQUAT/WIDE_STANCE_GOBLET_SQUAT": record(20, day: "2026-11-12")]
        #expect(StrengthLoadSuggestion.suggest(for: exercise("SQUAT/DUMBBELL_FRONT_SQUAT"), history: recent)?.baseId == "SQUAT/WIDE_STANCE_GOBLET_SQUAT")
        let tie = ["SQUAT/WIDE_STANCE_GOBLET_SQUAT": record(20), "SQUAT/GOBLET_SQUAT": record(16)]
        #expect(StrengthLoadSuggestion.suggest(for: exercise("SQUAT/DUMBBELL_FRONT_SQUAT"), history: tie)?.baseId == "SQUAT/GOBLET_SQUAT")
    }

    @Test func unilateral_base_never_feeds_a_bilateral_target() {
        #expect(StrengthLoadSuggestion.suggest(for: exercise("DEADLIFT/DUMBBELL_STRAIGHT_LEG_DEADLIFT"), history: ["HIP_RAISE/WEIGHTED_SINGLE_LEG_HIP_RAISE": record(10)]) == nil)
    }

    @Test func existing_record_is_not_overridden() throws {
        let session = TrainerStrengthSession(weekday: 2, group: .lower, legLoad: .heavy, name: "x", source: .trainer, intensity: .heavy, minutes: 60, place: .gym)
        let target = try #require(StrengthGenerator.workout(for: session, context: StrengthContext()).exercises.first).exerciseId
        let loads = [target: StrengthLoadRecord(weight: 40, completedAllSets: false, day: "2026-11-10")]
        let workout = StrengthGenerator.workout(for: session, context: StrengthContext(loads: loads))
        let first = try #require(workout.exercises.first { $0.exerciseId == target })
        #expect(first.weight == 40)
        #expect(first.suggestedLoad == nil)
    }

    @Test func apply_suggests_for_claude_exercises_without_weight() {
        let session = TrainerStrengthSession(weekday: 2, group: .lower, legLoad: .heavy, name: "x", source: .trainer, intensity: .heavy, minutes: 45, place: .gym)
        let target = exercise("SQUAT/DUMBBELL_FRONT_SQUAT")
        func item(_ weight: Double?) -> GeneratedExercise {
            GeneratedExercise(exerciseId: target.id, name: target.name, category: target.category, exerciseName: target.exerciseName, sets: 3, reps: 10, seconds: nil, restSeconds: 90, weight: weight, perSide: false)
        }
        func workout(_ weight: Double?) -> GeneratedStrengthWorkout {
            GeneratedStrengthWorkout(weekday: 2, group: .lower, intensity: .heavy, minutes: 45, place: .gym, exercises: [item(weight)], adjustments: [])
        }
        let context = StrengthContext(loads: ["SQUAT/GOBLET_SQUAT": record(16)])
        let suggested = ClaudeStrengthApply.apply(workout(nil), session: session, context: context)
        #expect(suggested.exercises.first?.weight == 12)
        #expect(suggested.exercises.first?.suggestedLoad?.baseId == "SQUAT/GOBLET_SQUAT")
        let kept = ClaudeStrengthApply.apply(workout(20), session: session, context: context)
        #expect(kept.exercises.first?.weight == 20)
        #expect(kept.exercises.first?.suggestedLoad == nil)
    }

    @Test func mfit_workouts_untouched() {
        let session = TrainerStrengthSession(weekday: 2, group: .lower, legLoad: .heavy, name: "x", source: .mfit, intensity: .heavy, minutes: 45, place: .gym)
        let target = exercise("SQUAT/DUMBBELL_FRONT_SQUAT")
        let item = GeneratedExercise(exerciseId: target.id, name: target.name, category: target.category, exerciseName: target.exerciseName, sets: 3, reps: 10, seconds: nil, restSeconds: 90, weight: nil, perSide: false)
        let workout = GeneratedStrengthWorkout(weekday: 2, group: .lower, intensity: .heavy, minutes: 45, place: .gym, exercises: [item], adjustments: [])
        let result = ClaudeStrengthApply.apply(workout, session: session, context: StrengthContext(loads: ["SQUAT/GOBLET_SQUAT": record(16)]))
        #expect(result.exercises.first?.weight == nil)
        #expect(result.exercises.first?.suggestedLoad == nil)
    }
}
