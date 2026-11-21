import Foundation
import GarminAPI
import Insights
import MFIT
import Storage
import Testing
import TrainingCore
@testable import trAIning

@MainActor @Suite struct StrengthPlannedLegsTests {
    private let today = Day.today()
    private var monday: Day { today.weekStart }

    private func makeModel(today: Day? = nil) throws -> (TrainerModel, StrengthPlanStore, ClaudeStrengthStore) {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let defaults = UserDefaults(suiteName: "legs-" + UUID().uuidString)!
        let planStore = StrengthPlanStore(url: folder.appending(path: "plan.json"), stamps: SyncDocumentStamp(defaults: defaults, syncedKey: StrengthPlanStoreConstants.syncedStampKey, documentKey: StrengthPlanStoreConstants.documentStampKey))
        let claude = ClaudeStrengthStore(defaults: UserDefaults(suiteName: "legs-claude-" + UUID().uuidString)!)
        let day = today ?? self.today
        let model = TrainerModel(
            container: try TrainingSchema.container(inMemory: true),
            store: TrainerStore(url: folder.appending(path: "trainer.json"), defaults: defaults),
            today: { day }, defaults: defaults, strengthPlanStore: planStore, claudeStore: claude
        )
        return (model, planStore, claude)
    }

    private func activate(_ group: TrainerStrengthGroup, intensity: TrainerStrengthIntensity, model: TrainerModel, store: StrengthPlanStore) throws {
        let session = TrainerStrengthSession(
            weekday: 1, group: group, legLoad: StrengthSessions.legLoad(group: group, intensity: intensity), name: "S", source: .trainer, intensity: intensity
        )
        try store.save(StrengthPlan(objective: .strength, sessions: [session], start: monday.adding(days: -7), validity: .weeks(4), builder: .trainer))
        model.reloadStrengthPlan()
    }

    private func exercise(_ id: String, sets: Int) throws -> GeneratedExercise {
        let item = try #require(StrengthCatalog.exercise(id))
        return GeneratedExercise(
            exerciseId: item.id, name: item.name, category: item.category, exerciseName: item.exerciseName,
            sets: sets, reps: 8, seconds: nil, restSeconds: 120, weight: nil, perSide: false
        )
    }

    @Test func trainerHeavyLegDayCounts() throws {
        let (model, planStore, _) = try makeModel()
        try activate(.lower, intensity: .moderate, model: model, store: planStore)
        let legs = try #require(model.plannedLegs(on: monday))
        #expect(legs.sets >= legs.legSets)
    }

    @Test func trainerLightOrUpperDayDoesNotCount() throws {
        let (model, planStore, _) = try makeModel()
        try activate(.upper, intensity: .heavy, model: model, store: planStore)
        #expect(model.plannedLegs(on: monday) == nil)
        try activate(.fullBody, intensity: .moderate, model: model, store: planStore)
        #expect(model.plannedLegs(on: monday) == nil)
    }

    @Test func claudeHeavyLegWorkoutCounts() throws {
        let (model, _, claude) = try makeModel(today: monday.adding(days: 1))
        let exercises = [try exercise("agachamento-livre", sets: 4), try exercise("terra-romeno", sets: 3), try exercise("prancha", sets: 2)]
        let workout = GeneratedStrengthWorkout(weekday: 1, group: .lower, intensity: .moderate, minutes: 45, place: .gym, exercises: exercises, adjustments: [])
        claude.apply([ClaudeDayResult(rawDay: monday.iso, day: monday, why: nil, workout: workout, errors: [], warnings: [])], summary: nil)
        #expect(model.plannedLegs(on: monday) == StrengthPlannedLegs(sets: 9, legSets: 7))
        #expect(model.plannedLegs(on: monday.adding(days: 1)) == nil)
    }

    @Test func plannedLegsNeedAStrengthSessionYesterday() {
        let yesterday = Day(iso: "2026-11-18")!
        let planned = StrengthPlannedLegs(sets: 12, legSets: 9)
        let session = StrengthSession(id: 5, day: yesterday, title: "Pernas (treinador)", minutes: 40, averageHR: 100, maxHR: 140, workoutId: nil, effort: 3)
        let leg = StrengthModel.legDay(sessions: [session], known: [:], planned: planned, before: Day(iso: "2026-11-19")!)
        #expect(leg == StrengthLegDay(title: "Pernas", sets: 12, legSets: 9))
        #expect(StrengthModel.legDay(sessions: [], known: [:], planned: planned, before: Day(iso: "2026-11-19")!) == nil)
        #expect(StrengthModel.legDay(sessions: [session], known: [:], before: Day(iso: "2026-11-19")!) == nil)
    }

    @Test func mfitUpperSessionIsNotCountedAsThePlannedLegDay() {
        let upper = MFITWorkout(id: 2, title: "Superiores", order: 1, blocks: [
            StrengthBlock(exercises: [StrengthExercise(name: "Supino", detail: nil, category: "BENCH_PRESS", exerciseKey: nil, reps: 10, seconds: nil)], sets: 20, restSeconds: 60),
        ], completions: [])
        let session = StrengthSession(id: 5, day: Day(iso: "2026-11-18")!, title: "Superiores", minutes: 40, averageHR: 100, maxHR: 140, workoutId: 2, effort: 3)
        let planned = StrengthPlannedLegs(sets: 12, legSets: 9)
        #expect(StrengthModel.legDay(sessions: [session], known: [2: upper], planned: planned, before: Day(iso: "2026-11-19")!) == nil)
    }
}
