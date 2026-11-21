import Foundation
import Insights
import TrainingCore
import UIKit

enum StrengthPlanEndNotifier {
    private typealias C = StrengthPlanEndConstants

    @MainActor static var runsOnPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    static func check(
        plan: StrengthPlan?, history: TrainerHistory, now: Date, calendar: Calendar, scheduler: any NotificationScheduling,
        canNotify: Bool = true, save: @Sendable (StrengthPlan) throws -> Void = { _ in }
    ) async -> StrengthPlan? {
        guard let plan, plan.endedNotifiedAt == nil, let last = plan.lastSessionDay(),
              let fireAt = calendar.date(bySettingHour: C.notifyHour, minute: 0, second: 0, of: date(of: last, calendar: calendar))
        else {
            await scheduler.cancel(id: C.notificationId)
            return nil
        }
        if now >= fireAt {
            await scheduler.cancel(id: C.notificationId)
            return persisted(plan, at: now, save: save)
        }
        guard canNotify else {
            await scheduler.cancel(id: C.notificationId)
            return nil
        }
        let lastDone = history.strength.contains { $0.day == last }
        let ended = lastDone ? persisted(plan, at: now, save: save) : nil
        if lastDone && ended == nil { return nil }
        await scheduler.schedule(
            id: C.notificationId, title: StrengthPlanEndText.title(plan.objective),
            text: StrengthPlanEndText.body(done: completed(plan, history: history), planned: plan.plannedCount()),
            link: DeepLinkConstants.trainerStrength, at: lastDone ? nil : fireAt
        )
        return ended
    }

    private static func completed(_ plan: StrengthPlan, history: TrainerHistory) -> Int {
        plan.doneCount(doneDays: Set(history.strength.map(\.day)))
    }

    private static func persisted(_ plan: StrengthPlan, at now: Date, save: @Sendable (StrengthPlan) throws -> Void) -> StrengthPlan? {
        var ended = plan
        ended.endedNotifiedAt = now
        do { try save(ended) } catch { return nil }
        return ended
    }

    private static func date(of day: Day, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .distantPast
    }
}
