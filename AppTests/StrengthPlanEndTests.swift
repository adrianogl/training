import Foundation
import Insights
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
}
