import Foundation
import Insights
import Storage
import SwiftData
import Sync
import Testing
import TrainingCore
@testable import trAIning

@Suite struct StrengthPlanEndTests {
    private let calendar = Calendar.current
    private let start = Day(year: 2026, month: 11, day: 16)

    private func session(_ weekday: Int) -> TrainerStrengthSession {
        TrainerStrengthSession(weekday: weekday, group: .upper, legLoad: .light, name: "S", source: .trainer)
    }

    private func plan(weekdays: [Int] = [1, 3], weeks: Int = 1, objective: StrengthObjective = .strength) -> StrengthPlan {
        StrengthPlan(objective: objective, sessions: weekdays.map(session), start: start, validity: .weeks(weeks), builder: .trainer)
    }

    private func date(_ day: Day, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour))!
    }

    private func history(_ days: [Day]) -> TrainerHistory {
        var history = TrainerHistory(runs: [])
        history.strength = days.enumerated().map { TrainerStrengthDone(activityId: Int64($0.offset), day: $0.element, name: "F", seconds: 1_800) }
        return history
    }

    @Test func schedules_21h_on_last_session_day() async {
        let scheduler = FakeNotificationScheduler()
        let last = start.adding(days: 2)
        let result = await StrengthPlanEndNotifier.check(
            plan: plan(), history: history([start]), now: date(start, hour: 9), calendar: calendar, scheduler: scheduler
        )
        #expect(result == nil)
        let entry = await scheduler.scheduled[StrengthPlanEndConstants.notificationId]
        #expect(entry?.at == date(last, hour: 21))
        #expect(entry?.text == "Foram 1 de 2 treinos. Toque para montar o próximo.")
        let header = await scheduler.headers[StrengthPlanEndConstants.notificationId]
        #expect(header?.title == "Plano de força terminou")
        #expect(header?.link == DeepLinkConstants.trainerStrength)
    }

    @Test func claude_plan_starting_next_week_schedules_on_its_own_last_day() async {
        let scheduler = FakeNotificationScheduler()
        let future = start.adding(days: 7)
        let claude = StrengthPlan(objective: .strength, sessions: [1, 3].map(session), start: future, validity: .weeks(1), builder: .claude)
        let result = await StrengthPlanEndNotifier.check(
            plan: claude, history: history([]), now: date(start, hour: 9), calendar: calendar, scheduler: scheduler
        )
        #expect(result == nil)
        #expect(await scheduler.delivered.isEmpty)
        let entry = await scheduler.scheduled[StrengthPlanEndConstants.notificationId]
        #expect(entry?.at == date(future.adding(days: 2), hour: 21))
        #expect(entry?.text == "Foram 0 de 2 treinos. Toque para montar o próximo.")
    }

    @Test func fires_now_when_last_workout_done() async {
        let scheduler = FakeNotificationScheduler()
        let last = start.adding(days: 2)
        let now = date(last, hour: 14)
        let result = await StrengthPlanEndNotifier.check(
            plan: plan(), history: history([start, last]), now: now, calendar: calendar, scheduler: scheduler
        )
        #expect(result?.endedNotifiedAt == now)
        #expect(await scheduler.delivered == [StrengthPlanEndConstants.notificationId])
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId]?.text == "Foram 2 de 2 treinos. Toque para montar o próximo.")
    }

    @Test func only_once_per_plan() async {
        let scheduler = FakeNotificationScheduler()
        let last = start.adding(days: 2)
        let first = await StrengthPlanEndNotifier.check(
            plan: plan(), history: history([last]), now: date(last, hour: 14), calendar: calendar, scheduler: scheduler
        )
        let second = await StrengthPlanEndNotifier.check(
            plan: first, history: history([last]), now: date(last, hour: 15), calendar: calendar, scheduler: scheduler
        )
        #expect(second == nil)
        #expect(await scheduler.delivered.count == 1)
    }

    @Test func marks_without_notifying_after_the_scheduled_time() async {
        let scheduler = FakeNotificationScheduler()
        let now = date(start.adding(days: 3), hour: 8)
        let result = await StrengthPlanEndNotifier.check(plan: plan(), history: history([]), now: now, calendar: calendar, scheduler: scheduler)
        #expect(result?.endedNotifiedAt == now)
        #expect(await scheduler.delivered.isEmpty)
        #expect(await scheduler.scheduled.isEmpty)
    }

    @Test func edit_reschedules() async {
        let scheduler = FakeNotificationScheduler()
        let now = date(start, hour: 9)
        _ = await StrengthPlanEndNotifier.check(plan: plan(), history: history([]), now: now, calendar: calendar, scheduler: scheduler)
        let edited = plan(weekdays: [1, 5])
        _ = await StrengthPlanEndNotifier.check(plan: edited, history: history([]), now: now, calendar: calendar, scheduler: scheduler)
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId]?.at == date(start.adding(days: 4), hour: 21))
    }

    @Test func delete_cancels() async {
        let scheduler = FakeNotificationScheduler()
        let now = date(start, hour: 9)
        _ = await StrengthPlanEndNotifier.check(plan: plan(), history: history([]), now: now, calendar: calendar, scheduler: scheduler)
        let result = await StrengthPlanEndNotifier.check(plan: nil, history: history([]), now: now, calendar: calendar, scheduler: scheduler)
        #expect(result == nil)
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId] == nil)
    }

    @Test func ipad_never_schedules_or_fires() async {
        let scheduler = FakeNotificationScheduler()
        let last = start.adding(days: 2)
        let before = await StrengthPlanEndNotifier.check(
            plan: plan(), history: history([last]), now: date(last, hour: 14), calendar: calendar, scheduler: scheduler, canNotify: false
        )
        #expect(before == nil)
        #expect(await scheduler.scheduled.isEmpty)
        #expect(await scheduler.delivered.isEmpty)
        let now = date(last, hour: 22)
        let after = await StrengthPlanEndNotifier.check(
            plan: plan(), history: history([]), now: now, calendar: calendar, scheduler: scheduler, canNotify: false
        )
        #expect(after?.endedNotifiedAt == now)
        #expect(await scheduler.delivered.isEmpty)
    }

    @Test func failed_save_delivers_nothing() async {
        struct Failure: Error {}
        let scheduler = FakeNotificationScheduler()
        let last = start.adding(days: 2)
        let result = await StrengthPlanEndNotifier.check(
            plan: plan(), history: history([last]), now: date(last, hour: 14), calendar: calendar, scheduler: scheduler,
            save: { _ in throw Failure() }
        )
        #expect(result == nil)
        #expect(await scheduler.delivered.isEmpty)
    }

    @Test func plan_without_sessions_cancels_without_marking() async {
        let scheduler = FakeNotificationScheduler()
        let now = date(start, hour: 9)
        _ = await StrengthPlanEndNotifier.check(plan: plan(), history: history([]), now: now, calendar: calendar, scheduler: scheduler)
        let result = await StrengthPlanEndNotifier.check(plan: plan(weekdays: []), history: history([]), now: now, calendar: calendar, scheduler: scheduler)
        #expect(result == nil)
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId] == nil)
    }

    @Test func reschedules_count_when_history_changes() async {
        let scheduler = FakeNotificationScheduler()
        let now = date(start, hour: 9)
        _ = await StrengthPlanEndNotifier.check(plan: plan(), history: history([]), now: now, calendar: calendar, scheduler: scheduler)
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId]?.text.hasPrefix("Foram 0 de 2") == true)
        _ = await StrengthPlanEndNotifier.check(plan: plan(), history: history([start]), now: now, calendar: calendar, scheduler: scheduler)
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId]?.text.hasPrefix("Foram 1 de 2") == true)
    }

    @Test func counts_only_plan_weekdays_within_validity() async {
        let scheduler = FakeNotificationScheduler()
        let outside = [start.adding(days: 1), start.adding(days: -7), start.adding(days: 7)]
        _ = await StrengthPlanEndNotifier.check(
            plan: plan(), history: history(outside + [start]), now: date(start, hour: 9), calendar: calendar, scheduler: scheduler
        )
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId]?.text.hasPrefix("Foram 1 de 2") == true)
    }

    @MainActor @Test func extending_plan_resets_ended_mark() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let defaults = UserDefaults(suiteName: "planend-" + UUID().uuidString)!
        let store = StrengthPlanStore(url: folder.appending(path: "plan.json"), stamps: nil)
        let model = TrainerModel(
            container: try TrainingSchema.container(inMemory: true),
            store: TrainerStore(url: folder.appending(path: "trainer.json"), defaults: defaults),
            defaults: defaults, strengthPlanStore: store, claudeStore: ClaudeStrengthStore(defaults: UserDefaults(suiteName: "planend-c-" + UUID().uuidString)!),
            planEndScheduler: FakeNotificationScheduler(), canNotifyPlanEnd: true
        )
        var ended = plan()
        ended.endedNotifiedAt = Date()
        try store.save(ended)
        model.reloadStrengthPlan()
        var longer = ended
        longer.validity = .weeks(3)
        await model.saveStrengthPlan(longer)
        #expect(store.current()?.endedNotifiedAt == nil)
        var renamed = longer
        renamed.endedNotifiedAt = Date()
        await model.saveStrengthPlan(renamed)
        #expect(store.current()?.endedNotifiedAt != nil)
    }

    @MainActor private func makeModel(today: Day, scheduler: FakeNotificationScheduler, container: ModelContainer) -> (TrainerModel, StrengthPlanStore) {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let defaults = UserDefaults(suiteName: "planend-" + UUID().uuidString)!
        let store = StrengthPlanStore(url: folder.appending(path: "plan.json"), stamps: nil)
        let model = TrainerModel(
            container: container, store: TrainerStore(url: folder.appending(path: "trainer.json"), defaults: defaults), today: { today },
            defaults: defaults, strengthPlanStore: store, claudeStore: ClaudeStrengthStore(defaults: UserDefaults(suiteName: "planend-c-" + UUID().uuidString)!),
            planEndScheduler: scheduler, canNotifyPlanEnd: true
        )
        return (model, store)
    }

    @MainActor @Test func remote_end_cancels_scheduled_notification() async throws {
        let scheduler = FakeNotificationScheduler()
        let future = Day(year: 2030, month: 1, day: 7)
        let (model, store) = makeModel(today: future, scheduler: scheduler, container: try TrainingSchema.container(inMemory: true))
        try store.save(StrengthPlan(objective: .strength, sessions: [session(1)], start: future, validity: .weeks(1), builder: .trainer))
        await model.reloadRemoteStrengthPlan()
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId]?.at == date(future, hour: 21))
        try store.clear()
        await model.reloadRemoteStrengthPlan()
        #expect(model.strengthPlan == nil)
        #expect(await scheduler.scheduled[StrengthPlanEndConstants.notificationId] == nil)
    }

    @MainActor @Test func consecutive_checks_after_last_workout_deliver_once() async throws {
        let scheduler = FakeNotificationScheduler()
        let future = Day(year: 2030, month: 1, day: 7)
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(ActivityRecord(
            activityId: 1, typeKey: "strength_training", name: "Força", start: date(future, hour: 12),
            distance: 0, duration: 1_800, movingDuration: 1_800
        ))
        try context.save()
        let (model, store) = makeModel(today: future, scheduler: scheduler, container: container)
        await model.load()
        try store.save(StrengthPlan(objective: .strength, sessions: [session(1)], start: future, validity: .weeks(1), builder: .trainer))
        model.reloadStrengthPlan()
        async let first: Void = model.checkStrengthPlanEnd()
        async let second: Void = model.checkStrengthPlanEnd()
        _ = await (first, second)
        #expect(await scheduler.delivered == [StrengthPlanEndConstants.notificationId])
        #expect(store.current()?.endedNotifiedAt != nil)
    }
}
