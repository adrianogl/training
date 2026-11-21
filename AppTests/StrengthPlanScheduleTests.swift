import Foundation
import Insights
import Storage
import Testing
import TrainingCore
@testable import trAIning

@MainActor @Suite struct StrengthPlanScheduleTests {
    private let today = Day.today()
    private var nextMonday: Day { today.weekStart.adding(days: 7) }
    private var nextTuesday: Day { nextMonday.adding(days: 1) }
    private var nextThursday: Day { nextMonday.adding(days: 3) }

    private func session(_ weekday: Int, source: TrainerStrengthSource = .trainer, group: TrainerStrengthGroup = .upper) -> TrainerStrengthSession {
        TrainerStrengthSession(weekday: weekday, group: group, legLoad: .light, name: "S", source: source)
    }

    private func makeModel() throws -> (TrainerModel, StrengthPlanStore, ClaudeStrengthStore) {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let defaults = UserDefaults(suiteName: "schedule-" + UUID().uuidString)!
        let planStore = StrengthPlanStore(url: folder.appending(path: "plan.json"), stamps: SyncDocumentStamp(defaults: defaults, syncedKey: StrengthPlanStoreConstants.syncedStampKey, documentKey: StrengthPlanStoreConstants.documentStampKey))
        let claude = ClaudeStrengthStore(defaults: UserDefaults(suiteName: "schedule-claude-" + UUID().uuidString)!)
        let day = today
        let model = TrainerModel(
            container: try TrainingSchema.container(inMemory: true),
            store: TrainerStore(url: folder.appending(path: "trainer.json"), defaults: defaults),
            today: { day }, defaults: defaults, strengthPlanStore: planStore, claudeStore: claude
        )
        return (model, planStore, claude)
    }

    private func activate(_ plan: StrengthPlan, in model: TrainerModel, store: StrengthPlanStore) throws {
        try store.save(plan)
        model.reloadStrengthPlan()
    }

    private func createRunningPlan(_ model: TrainerModel, strength: [TrainerStrengthSession]) async {
        let target = TrainerTarget(kind: .race, name: "Meia", date: today.adding(days: 70), distanceMeters: 21_097.5, goalSeconds: 5_940)
        await model.createPlan(target: target, structure: TrainerEngine.defaultStructure, strength: strength, startMeters: 60_000, peakMeters: 80_000)
    }

    private func workout(_ weekday: Int) -> GeneratedStrengthWorkout {
        GeneratedStrengthWorkout(weekday: weekday, group: .core, intensity: .light, minutes: 20, place: .home, exercises: [], adjustments: [])
    }

    private func store(_ claude: ClaudeStrengthStore, day: Day, planId: UUID?, replacesMFIT: Bool = false) {
        var result = ClaudeDayResult(rawDay: day.iso, day: day, why: "porque", workout: workout(day.weekStart.days(until: day) + 1), errors: [], warnings: [])
        result.replacesMFIT = replacesMFIT
        claude.apply([result], summary: nil, planId: planId)
    }

    @Test func no_plan_sessions_after_end() throws {
        let (model, planStore, _) = try makeModel()
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(1), builder: .trainer)
        try activate(plan, in: model, store: planStore)
        #expect(model.trainerSessions(on: nextTuesday).count == 1)
        #expect(model.trainerSessions(on: nextTuesday.adding(days: 7)).isEmpty)
    }

    @Test func no_plan_sessions_before_start() throws {
        let (model, planStore, _) = try makeModel()
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(4), builder: .trainer)
        try activate(plan, in: model, store: planStore)
        #expect(model.trainerSessions(on: nextTuesday.adding(days: -7)).isEmpty)
        #expect(model.trainerSessions(on: nextTuesday).count == 1)
    }

    @Test func no_active_plan_has_no_trainer_sessions() throws {
        let (model, _, _) = try makeModel()
        #expect(model.trainerSessions(on: nextTuesday).isEmpty)
    }

    @Test func mfit_day_shows_both_mfit_and_plan() async throws {
        let (model, planStore, _) = try makeModel()
        await createRunningPlan(model, strength: [session(2, source: .mfit)])
        let plan = StrengthPlan(objective: .mobility, sessions: [session(2, group: .mobility)], start: nextMonday, validity: .weeks(4), builder: .trainer)
        try activate(plan, in: model, store: planStore)
        let tuesday = model.strengthSessions.filter { $0.weekday == 2 }
        #expect(Set(tuesday.map(\.source)) == [.mfit, .trainer])
        #expect(!model.replacesMFIT(on: nextTuesday))
        #expect(model.trainerSessions(on: nextTuesday).map(\.group) == [.mobility])
        #expect(TrainerStrengthText.chipName(.mfit) == "MFIT")
        #expect(TrainerStrengthText.chipName(.trainer) == "Plano")
    }

    @Test func mfit_outside_plan_still_shows() async throws {
        let (model, planStore, _) = try makeModel()
        await createRunningPlan(model, strength: [session(2, source: .mfit)])
        let plan = StrengthPlan(objective: .strength, sessions: [session(4)], start: nextMonday, validity: .weeks(1), builder: .trainer)
        try activate(plan, in: model, store: planStore)
        let later = nextTuesday.adding(days: 14)
        #expect(model.trainerSessions(on: later).isEmpty)
        #expect(!model.replacesMFIT(on: later))
        #expect(model.strengthSessions.contains { $0.source == .mfit && $0.weekday == 2 })
    }

    @Test func claude_workout_of_old_plan_is_ignored() throws {
        let (model, planStore, claude) = try makeModel()
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(4), builder: .claude)
        try activate(plan, in: model, store: planStore)
        store(claude, day: nextTuesday, planId: UUID(), replacesMFIT: true)
        store(claude, day: nextThursday, planId: nil)
        #expect(model.claudeWorkout(on: nextTuesday) == nil)
        #expect(!model.isClaudeDay(nextTuesday))
        #expect(!model.replacesMFIT(on: nextTuesday))
        #expect(model.trainerSessions(on: nextTuesday).map(\.id) == plan.sessions.map(\.id))
        #expect(model.claudeWorkout(on: nextThursday) != nil)
    }

    @Test func claude_workout_of_active_plan_outside_validity_is_ignored() throws {
        let (model, planStore, claude) = try makeModel()
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(1), builder: .claude)
        try activate(plan, in: model, store: planStore)
        store(claude, day: nextTuesday, planId: plan.id)
        store(claude, day: nextTuesday.adding(days: 7), planId: plan.id)
        #expect(model.claudeWorkout(on: nextTuesday) != nil)
        #expect(model.claudeWorkout(on: nextTuesday.adding(days: 7)) == nil)
    }

    @Test func plan_workout_never_replaces_mfit() async throws {
        let (model, planStore, claude) = try makeModel()
        await createRunningPlan(model, strength: [session(2, source: .mfit)])
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(4), builder: .claude)
        try activate(plan, in: model, store: planStore)
        store(claude, day: nextTuesday, planId: plan.id, replacesMFIT: true)
        #expect(model.claudeWorkout(on: nextTuesday) != nil)
        #expect(model.claudeOverride(on: nextTuesday) == nil)
        #expect(!model.replacesMFIT(on: nextTuesday))
        #expect(model.trainerSessions(on: nextTuesday).map(\.id) == plan.sessions.map(\.id))
    }

    @Test func free_claude_override_keeps_replacing_mfit() throws {
        let (model, _, claude) = try makeModel()
        store(claude, day: nextTuesday, planId: nil, replacesMFIT: true)
        #expect(model.replacesMFIT(on: nextTuesday))
        #expect(model.trainerSessions(on: nextTuesday).count == 1)
    }

    @Test func edited_plan_drops_claude_days_that_left_the_plan() async throws {
        let (model, planStore, claude) = try makeModel()
        await createRunningPlan(model, strength: [session(3, source: .mfit)])
        let plan = StrengthPlan(objective: .strength, sessions: [session(2), session(4)], start: nextMonday, validity: .weeks(4), builder: .claude)
        try activate(plan, in: model, store: planStore)
        store(claude, day: nextTuesday, planId: plan.id)
        store(claude, day: nextThursday, planId: plan.id)
        store(claude, day: nextThursday.adding(days: 7), planId: nil)
        var edited = plan
        edited.sessions = [plan.sessions[0]]
        await model.saveStrengthPlan(edited)
        #expect(claude.workout(on: nextTuesday) != nil)
        #expect(claude.workout(on: nextThursday) == nil)
        #expect(claude.workout(on: nextThursday.adding(days: 7)) != nil)
        #expect(planStore.current()?.sessions.map(\.weekday) == [2])
        #expect(model.strengthPlan?.sessions.map(\.weekday) == [2])
        #expect(model.strengthSessions.contains { $0.source == .mfit && $0.weekday == 3 })
        #expect(model.plan?.strength.contains { $0.source == .mfit && $0.weekday == 3 } == true)
        #expect(model.plan?.strength.filter { $0.source == .trainer }.map(\.weekday) == [2])
    }

    @Test func editing_sessions_updates_active_plan_and_keeps_mfit() async throws {
        let (model, planStore, _) = try makeModel()
        await createRunningPlan(model, strength: [session(3, source: .mfit)])
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(4), builder: .trainer)
        try activate(plan, in: model, store: planStore)
        await model.saveStrength(model.strengthSessions + [session(5)])
        #expect(planStore.current()?.sessions.map(\.weekday).sorted() == [2, 5])
        #expect(model.strengthSessions.contains { $0.source == .mfit && $0.weekday == 3 })
        #expect(model.trainerSessions(on: nextMonday.adding(days: 4)).count == 1)
    }

    @Test func mfit_sync_keeps_plan_sessions_on_mfit_day() async throws {
        let (model, planStore, claude) = try makeModel()
        await createRunningPlan(model, strength: [session(3, source: .mfit)])
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(4), builder: .claude)
        await model.saveStrengthPlan(plan)
        store(claude, day: nextTuesday, planId: plan.id)
        await model.syncStrength([session(2, source: .mfit)])
        #expect(planStore.current()?.sessions == plan.sessions)
        #expect(model.strengthPlan?.sessions == plan.sessions)
        #expect(claude.workout(on: nextTuesday) != nil)
        #expect(Set(model.strengthSessions.filter { $0.weekday == 2 }.map(\.source)) == [.mfit, .trainer])
        #expect(!model.strengthSessions.contains { $0.source == .mfit && $0.weekday == 3 })
        #expect(model.trainerSessions(on: nextTuesday).map(\.id) == plan.sessions.map(\.id))
        #expect(!model.replacesMFIT(on: nextTuesday))
        #expect(Set(model.plan?.strength.filter { $0.weekday == 2 }.map(\.source) ?? []) == [.mfit, .trainer])
    }

    @Test func day_row_labels_mfit_plan_and_free_claude() async throws {
        let (model, _, claude) = try makeModel()
        await createRunningPlan(model, strength: [session(2, source: .mfit)])
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(4), builder: .claude)
        await model.saveStrengthPlan(plan)
        store(claude, day: nextTuesday, planId: plan.id)
        store(claude, day: nextThursday, planId: nil, replacesMFIT: true)
        let tuesday = try #require(model.row(for: nextTuesday.iso))
        #expect(Set(tuesday.strength.map(\.source)) == [.mfit, .trainer])
        #expect(tuesday.strength.allSatisfy { !$0.isClaude })
        let thursday = try #require(model.row(for: nextThursday.iso))
        #expect(thursday.strength.count == 1)
        #expect(thursday.strength.first?.isClaude == true)
        #expect(model.isFreeClaudeDay(nextThursday))
        #expect(!model.isFreeClaudeDay(nextTuesday))
    }

    @Test func day_row_hides_plan_lines_outside_validity() async throws {
        let (model, _, _) = try makeModel()
        await createRunningPlan(model, strength: [session(3, source: .mfit)])
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(1), builder: .trainer)
        await model.saveStrengthPlan(plan)
        let later = try #require(model.row(for: nextTuesday.adding(days: 14).iso))
        #expect(later.strength.isEmpty)
        let mfitDay = try #require(model.row(for: nextMonday.adding(days: 16).iso))
        #expect(mfitDay.strength.map(\.source) == [.mfit])
    }

    @Test func save_without_plan_keeps_free_claude_days() async throws {
        let (model, _, claude) = try makeModel()
        await createRunningPlan(model, strength: [session(4, source: .mfit)])
        #expect(model.strengthPlan == nil)
        store(claude, day: nextThursday, planId: nil)
        await model.saveStrength([session(2)])
        #expect(claude.workout(on: nextThursday) != nil)
        #expect(model.strengthPlan?.sessions.map(\.weekday) == [2])
    }

    @Test func creating_running_plan_keeps_strength_plan_and_engine_in_sync() async throws {
        let (model, planStore, _) = try makeModel()
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(4), builder: .trainer)
        try activate(plan, in: model, store: planStore)
        await createRunningPlan(model, strength: [session(4), session(3, source: .mfit)])
        #expect(planStore.current()?.sessions == plan.sessions)
        #expect(model.plan?.strength.filter { $0.source == .trainer }.map(\.weekday) == [2])
        #expect(model.plan?.strength.contains { $0.source == .mfit && $0.weekday == 3 } == true)
        #expect(model.strengthSessions.map(\.weekday).sorted() == [2, 3])
    }

    @Test func creating_running_plan_without_strength_plan_creates_one_from_form() async throws {
        let (model, planStore, _) = try makeModel()
        await createRunningPlan(model, strength: [session(4), session(3, source: .mfit)])
        let created = try #require(planStore.current())
        #expect(created.sessions.map(\.weekday) == [4])
        #expect(created.sessions.allSatisfy { $0.source == .trainer })
        #expect(!created.migrated)
        #expect(created.validity == .untilDate(today.adding(days: 70)))
        #expect(model.strengthPlan == created)
        #expect(model.plan?.strength.filter { $0.source == .trainer }.map(\.weekday) == [4])
        #expect(model.plan?.strength.contains { $0.source == .mfit && $0.weekday == 3 } == true)
        #expect(model.strengthSessions.map(\.weekday).sorted() == [3, 4])
    }

    @Test func weeks_done_counts_only_within_validity() {
        let plan = StrengthPlan(objective: .strength, sessions: [session(2)], start: nextMonday, validity: .weeks(2), builder: .trainer)
        let done = [nextTuesday.adding(days: -7), nextTuesday, nextTuesday.adding(days: 7), nextTuesday.adding(days: 14)].enumerated().map {
            TrainerStrengthDone(activityId: Int64($0.offset), day: $0.element, name: "F", seconds: 1_800)
        }
        let history = TrainerHistory(runs: [], strength: done)
        let scoped = TrainerModel.strengthHistory(history, for: session(2), plan: plan)
        #expect(scoped.strength.map(\.day) == [nextTuesday, nextTuesday.adding(days: 7)])
        #expect(TrainerModel.strengthHistory(history, for: session(2, source: .mfit), plan: plan).strength.count == 4)
        #expect(TrainerModel.strengthHistory(history, for: session(2), plan: nil).strength.isEmpty)
    }

    @Test func old_stored_workout_decodes_without_plan_id() throws {
        let old = ClaudeStoredWorkout(workout: workout(2), why: nil, summary: nil)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any] ?? [:]
        json["planId"] = nil
        let decoded = try JSONDecoder().decode(ClaudeStoredWorkout.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.planId == nil)
    }
}
