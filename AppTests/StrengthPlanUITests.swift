import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct StrengthPlanUITests {
    private let start = Day(iso: "2026-11-24")!

    private func plan(validity: StrengthPlanValidity = .weeks(8)) -> StrengthPlan {
        StrengthPlan(
            objective: .mobility, sessions: [2, 4].map { StrengthPlanDraftLogic.newSession(objective: .mobility, weekday: $0) },
            start: start, validity: validity, builder: .trainer
        )
    }

    private func model(
        defaults: UserDefaults = UserDefaults(suiteName: "planui-" + UUID().uuidString)!,
        store: StrengthPlanStore? = nil, container: ModelContainer? = nil, scheduler: FakeNotificationScheduler = FakeNotificationScheduler()
    ) throws -> (TrainerModel, StrengthPlanStore) {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let planStore = store ?? StrengthPlanStore(url: folder.appending(path: "plan.json"), stamps: nil)
        let model = TrainerModel(
            container: try container ?? TrainingSchema.container(inMemory: true),
            store: TrainerStore(url: folder.appending(path: "trainer.json"), defaults: defaults),
            defaults: defaults, strengthPlanStore: planStore,
            claudeStore: ClaudeStrengthStore(defaults: UserDefaults(suiteName: "planui-c-" + UUID().uuidString)!),
            planEndScheduler: scheduler, canNotifyPlanEnd: true
        )
        return (model, planStore)
    }

    @Test func save_keeps_stored_ended_mark_when_end_did_not_change() async throws {
        let (model, store) = try model()
        let stale = plan()
        try store.save(stale)
        model.reloadStrengthPlan()
        var notified = stale
        notified.endedNotifiedAt = Date(timeIntervalSince1970: 1_000)
        try store.save(notified)
        var edited = stale
        edited.builder = .claude
        await model.saveStrengthPlan(edited)
        #expect(store.current()?.endedNotifiedAt == Date(timeIntervalSince1970: 1_000))
        #expect(store.current()?.builder == .claude)
    }

    @Test func ending_plan_clears_store_and_cancels_notification() async throws {
        let scheduler = FakeNotificationScheduler()
        let (model, store) = try model(scheduler: scheduler)
        var future = plan()
        future.start = Day.today().adding(days: 1)
        await model.saveStrengthPlan(future)
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId] != nil)
        await model.endStrengthPlan()
        #expect(store.current() == nil)
        #expect(model.strengthPlan == nil)
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId] == nil)
    }

    @Test func migration_notice_shows_once_per_account() async throws {
        let defaults = UserDefaults(suiteName: "planui-m-" + UUID().uuidString)!
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let store = StrengthPlanStore(url: folder.appending(path: "plan.json"), stamps: nil)
        var migrated = plan()
        migrated.migrated = true
        try store.save(migrated)
        let (first, _) = try model(defaults: defaults, store: store)
        #expect(first.showsStrengthMigrationNotice)
        first.dismissStrengthMigrationNotice()
        #expect(!first.showsStrengthMigrationNotice)
        let (second, _) = try model(defaults: defaults, store: store)
        #expect(!second.showsStrengthMigrationNotice)
    }

    @Test func until_race_follows_moved_race_and_falls_back_to_date_when_removed() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let race = RaceRecord(name: "Meia", day: "2027-01-31", distance: 21_097.5)
        container.mainContext.insert(race)
        try container.mainContext.save()
        let (model, _) = try model(container: container)
        let original = plan(validity: .untilRace(raceId: race.id.uuidString, raceDay: Day(iso: "2027-01-24")!))
        #expect(model.resolvedStrengthPlan(original).validity == .untilRace(raceId: race.id.uuidString, raceDay: Day(iso: "2027-01-31")!))
        race.deletedAt = .now
        try container.mainContext.save()
        #expect(model.resolvedStrengthPlan(original).validity == .untilDate(Day(iso: "2027-01-23")!))
    }

    @Test func objective_sets_defaults_for_new_sessions() {
        let mobility = StrengthPlanDraftLogic.newSession(objective: .mobility, weekday: 2)
        #expect(mobility.group == .mobility && mobility.intensity == .light && mobility.minutes == 20 && mobility.place == .home)
        let strength = StrengthPlanDraftLogic.newSession(objective: .strength, weekday: 2)
        #expect(strength.group == .fullBody && strength.intensity == .moderate && strength.minutes == 45 && strength.place == .gym)
        let prevention = StrengthPlanDraftLogic.newSession(objective: .prevention, weekday: 2)
        #expect(prevention.group == .fullBody && prevention.intensity == .light && prevention.minutes == 30)
    }

    @Test func draft_round_trips_and_removed_race_shows_as_date() {
        let weeks = StrengthPlanDraftLogic.draft(from: plan(), race: nil, targetRace: nil)
        #expect(weeks.mode == .weeks && weeks.weeks == 8 && !weeks.isNew)
        #expect(StrengthPlanDraftLogic.plan(weeks)?.end == Day(iso: "2027-01-18")!)
        let orphan = plan(validity: .untilDate(Day(iso: "2027-01-23")!))
        let dated = StrengthPlanDraftLogic.draft(from: orphan, race: nil, targetRace: nil)
        #expect(dated.mode == .untilDate && dated.untilDate == Day(iso: "2027-01-23")!)
        var empty = StrengthPlanDraftLogic.empty(objective: .mobility, today: Day(iso: "2026-11-20")!, race: nil)
        #expect(StrengthPlanDraftLogic.plan(empty) == nil)
        empty.sessions = [StrengthPlanDraftLogic.newSession(objective: .mobility, weekday: 2)]
        #expect(StrengthPlanDraftLogic.defaultStart(empty.sessions, today: Day(iso: "2026-11-20")!) == start)
    }

    @Test func texts_match_the_mock() {
        let value = plan()
        let card = StrengthPlanDraftLogic.cardSummary(value, done: 6, today: Day(iso: "2026-12-08")!)
        #expect(card.title == "Mobilidade · ter e qui")
        #expect(card.period == "24/11 a 18/01 · 20 min · casa")
        #expect(card.progress == "Semana 3 de 8 · 6 de 16 treinos feitos")
        #expect(StrengthPlanText.summary(end: value.end, planned: value.plannedCount()) == "Termina seg. 18/01 · 16 treinos")
        let ended = StrengthPlanDraftLogic.endedSummary(value, done: 15)
        #expect(ended.title == "Plano de mobilidade terminou em 18/01")
        #expect(ended.body == "15 de 16 treinos feitos. Terças e quintas ficam sem treino do plano.")
        #expect(StrengthPlanText.migration(end: value.end) == "Seu treino de força virou um plano até 18/01. Ajuste a validade se quiser.")
        let mfit = StrengthPlanUITests.mfitSessions()
        #expect(StrengthPlanText.mfitTitle(mfit) == "Treino A, B e C")
        #expect(StrengthPlanText.mfitSubtitle(mfit, ended: false) == "seg, qua e sex · não muda com o plano")
    }

    static func mfitSessions() -> [TrainerStrengthSession] {
        [(1, "Treino A"), (3, "Treino B"), (5, "Treino C")].map {
            TrainerStrengthSession(weekday: $0.0, group: .fullBody, legLoad: .light, name: $0.1, source: .mfit)
        }
    }
}
