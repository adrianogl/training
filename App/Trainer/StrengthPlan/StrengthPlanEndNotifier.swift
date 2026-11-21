import Foundation
import Insights
import TrainingCore

enum StrengthPlanEndNotifier {
    private typealias C = StrengthPlanEndConstants

    static func check(
        plan: StrengthPlan?, history: TrainerHistory, now: Date, calendar: Calendar, scheduler: any NotificationScheduling
    ) async -> StrengthPlan? {
        guard let plan, plan.endedNotifiedAt == nil, let last = plan.lastSessionDay(),
              let fireAt = calendar.date(bySettingHour: C.notifyHour, minute: 0, second: 0, of: date(of: last, calendar: calendar))
        else {
            await scheduler.cancel(id: C.notificationId)
            return nil
        }
        if now >= fireAt {
            await scheduler.cancel(id: C.notificationId)
            return marked(plan, at: now)
        }
        let done = completed(plan, history: history)
        let lastDone = history.strength.contains { $0.day == last }
        await scheduler.schedule(
            id: C.notificationId, title: StrengthPlanEndText.title(plan.objective),
            text: StrengthPlanEndText.body(done: done, planned: plan.plannedCount()), link: DeepLinkConstants.trainerStrength,
            at: lastDone ? nil : fireAt
        )
        return lastDone ? marked(plan, at: now) : nil
    }

    private static func completed(_ plan: StrengthPlan, history: TrainerHistory) -> Int {
        let weekdays = Set(plan.sessions.map(\.weekday))
        let days = Set(history.strength.map(\.day)).filter { day in
            plan.isActive(on: day) && weekdays.contains(day.weekStart.days(until: day) + 1)
        }
        return days.count
    }

    private static func marked(_ plan: StrengthPlan, at now: Date) -> StrengthPlan {
        var ended = plan
        ended.endedNotifiedAt = now
        return ended
    }

    private static func date(of day: Day, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .distantPast
    }
}
