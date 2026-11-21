import Foundation
import Insights
import Storage
import Testing
import TrainingCore
@testable import trAIning

@MainActor @Suite struct ClaudePlanRequestTests {
    private let today = Day.today()
    private var nextMonday: Day { today.weekStart.adding(days: 7) }

    private func session(_ weekday: Int, group: TrainerStrengthGroup = .upper, source: TrainerStrengthSource = .trainer) -> TrainerStrengthSession {
        TrainerStrengthSession(weekday: weekday, group: group, legLoad: .light, name: "S", source: source, intensity: .moderate, minutes: 40, place: .gym)
    }

    private func makeModel(plan: StrengthPlan?) throws -> (TrainerModel, ClaudeStrengthStore) {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let defaults = UserDefaults(suiteName: "plan-request-" + UUID().uuidString)!
        let planStore = StrengthPlanStore(url: folder.appending(path: "plan.json"), stamps: SyncDocumentStamp(defaults: defaults, syncedKey: StrengthPlanStoreConstants.syncedStampKey, documentKey: StrengthPlanStoreConstants.documentStampKey))
        let claude = ClaudeStrengthStore(defaults: UserDefaults(suiteName: "plan-request-claude-" + UUID().uuidString)!)
        let day = today
        let model = TrainerModel(
            container: try TrainingSchema.container(inMemory: true),
            store: TrainerStore(url: folder.appending(path: "trainer.json"), defaults: defaults),
            today: { day }, defaults: defaults, strengthPlanStore: planStore, claudeStore: claude
        )
        if let plan {
            try planStore.save(plan)
            model.reloadStrengthPlan()
        }
        return (model, claude)
    }

    private func claudePlan(start: Day? = nil, weeks: Int = 4, sessions: [TrainerStrengthSession]? = nil) -> StrengthPlan {
        StrengthPlan(objective: .strength, sessions: sessions ?? [session(2, group: .upper), session(4, group: .lower)], start: start ?? nextMonday, validity: .weeks(weeks), builder: .claude)
    }

    private func json(_ days: [(String, Bool)]) -> String {
        let items = days.map { day, replaces in
            """
            {"dia":"\(day)","foco":"upper","minutos":40,"local":"gym","porque":"x","substitui_mfit":\(replaces),"exercicios":[{"id":"PLANK/PLANK","series":3,"segundos":30}]}
            """
        }
        return "{\"versao\":1,\"resumo\":\"r\",\"treinos\":[\(items.joined(separator: ","))]}"
    }

    @Test func request_period_is_plan_range() throws {
        let plan = claudePlan()
        let (model, _) = try makeModel(plan: plan)
        let period = model.claudePeriod(.nextWeek, race: nil)
        #expect(period.first == plan.start)
        #expect(period.last == plan.end)
    }

    @Test func request_period_starts_tomorrow_when_plan_already_started() throws {
        let plan = claudePlan(start: today.adding(days: -3))
        let (model, _) = try makeModel(plan: plan)
        let period = model.claudePeriod(.untilRace, race: nil)
        #expect(period.first == today.adding(days: 1))
        #expect(period.last == plan.end)
    }

    @Test func request_days_are_plan_days() throws {
        let plan = claudePlan(sessions: [session(2, group: .upper), session(5, group: .core)])
        let (model, _) = try makeModel(plan: plan)
        let payload = ClaudeContextBuilder.payload(model.claudeContextInput(.nextWeek, race: nil))
        #expect(payload.dias_do_treinador.map(\.dia_da_semana) == ["ter", "sex"])
        #expect(payload.dias_do_treinador.map(\.foco) == [TrainerStrengthGroup.upper.rawValue, TrainerStrengthGroup.core.rawValue])
        #expect(payload.periodo.inicio == plan.start.iso)
        #expect(payload.periodo.fim == plan.end.iso)
    }

    @Test func import_tags_plan_id() throws {
        let plan = claudePlan()
        let (model, claude) = try makeModel(plan: plan)
        let tuesday = plan.start.adding(days: 1)
        let state = model.claudeImportState(parsing: json([(tuesday.iso, false)]), race: nil)
        #expect(state.planId == plan.id)
        #expect(state.results.allSatisfy { $0.isValid })
        model.applyClaudeImport(state)
        #expect(claude.workout(on: tuesday)?.planId == plan.id)
    }

    @Test func import_never_sets_replaces_mfit_for_plan() throws {
        let plan = claudePlan(sessions: [session(2), session(4), session(1, group: .lower, source: .mfit)])
        let (model, claude) = try makeModel(plan: plan)
        let tuesday = plan.start.adding(days: 1)
        let state = model.claudeImportState(parsing: json([(tuesday.iso, true)]), race: nil)
        #expect(state.results.allSatisfy { !$0.replacesMFIT })
        model.applyClaudeImport(state)
        #expect(claude.workout(on: tuesday)?.replacesMFIT == nil)
        #expect(claude.workout(on: tuesday)?.overridesMFIT == false)
    }

    @Test func import_rejects_days_outside_plan_range() throws {
        let plan = claudePlan(weeks: 1)
        let (model, claude) = try makeModel(plan: plan)
        let outside = plan.end.adding(days: 8)
        let state = model.claudeImportState(parsing: json([(outside.iso, false)]), race: nil)
        #expect(state.results.first?.errors.contains(.outOfPeriod) == true)
        model.applyClaudeImport(state)
        #expect(claude.workout(on: outside) == nil)
    }

    @Test func free_request_unchanged_without_plan() throws {
        let (model, claude) = try makeModel(plan: nil)
        let period = model.claudePeriod(.nextWeek, race: nil)
        #expect(period.first == today.weekStart.adding(days: 7))
        #expect(period.last == period.first.adding(days: 6))
        let tuesday = nextMonday.adding(days: 1)
        let state = model.claudeImportState(parsing: json([(tuesday.iso, false)]), race: nil)
        #expect(state.planId == nil)
        model.applyClaudeImport(state)
        #expect(claude.workout(on: tuesday)?.planId == nil)
    }

    @Test func plan_ending_today_falls_back_to_free_request() throws {
        let plan = claudePlan(start: today.adding(days: -27), weeks: 4)
        #expect(plan.end == today)
        let (model, _) = try makeModel(plan: plan)
        #expect(model.claudeBuildingPlan == nil)
        let period = model.claudePeriod(.nextWeek, race: nil)
        #expect(period.first == today.weekStart.adding(days: 7))
    }

    @Test func import_rejects_day_not_on_plan_weekday() throws {
        let plan = claudePlan()
        let (model, claude) = try makeModel(plan: plan)
        let wednesday = plan.start.adding(days: 2)
        let state = model.claudeImportState(parsing: json([(wednesday.iso, false)]), race: nil)
        #expect(!state.results[0].isValid)
        #expect(model.planNotice(for: state) != nil)
        model.applyClaudeImport(state)
        #expect(claude.workout(on: wednesday) == nil)
    }

    @Test func request_period_starts_at_plan_start_when_in_future() throws {
        let plan = claudePlan(start: today.adding(days: 20))
        let (model, _) = try makeModel(plan: plan)
        #expect(model.claudePeriod(.nextWeek, race: nil).first == plan.start)
    }

    @Test func request_days_ignore_mfit_sessions() throws {
        let plan = claudePlan(sessions: [session(2), session(3, source: .mfit), session(5)])
        let (model, _) = try makeModel(plan: plan)
        let payload = ClaudeContextBuilder.payload(model.claudeContextInput(.nextWeek, race: nil))
        #expect(payload.dias_do_treinador.map(\.dia_da_semana) == ["ter", "sex"])
    }
}
