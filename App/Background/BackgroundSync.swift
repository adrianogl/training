import BackgroundTasks
import Foundation

enum BackgroundSync {
    private typealias C = BackgroundConstants

    static func register(model: AppModel) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: C.refreshTaskId, using: .main) { task in
            nonisolated(unsafe) let task = task
            MainActor.assumeIsolated { handle(task, model: model) }
        }
    }

    static func schedule(now: Date = .now, calendar: Calendar = .current, readinessComplete: Bool = true) {
        let request = BGAppRefreshTaskRequest(identifier: C.refreshTaskId)
        request.earliestBeginDate = nextBeginDate(after: now, calendar: calendar, readinessComplete: readinessComplete)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func nextBeginDate(after now: Date, calendar: Calendar, readinessComplete: Bool) -> Date {
        let today = calendar.startOfDay(for: now)
        let refreshToday = calendar.date(bySettingHour: C.refreshHour, minute: 0, second: 0, of: today) ?? now
        if now < refreshToday { return refreshToday }
        let retry = now.addingTimeInterval(C.retryInterval)
        let ceiling = calendar.date(bySettingHour: C.retryCeilingHour, minute: 0, second: 0, of: today) ?? now
        if !readinessComplete, retry < ceiling { return retry }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        return calendar.date(bySettingHour: C.refreshHour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    @MainActor private static func handle(_ task: BGTask, model: AppModel) {
        schedule()
        nonisolated(unsafe) let task = task
        task.expirationHandler = { @Sendable in
            Task { @MainActor in model.cancelSync() }
        }
        Task {
            let succeeded = await model.syncNow(.background)
            schedule(readinessComplete: model.todayReadinessComplete)
            task.setTaskCompleted(success: succeeded)
        }
    }
}
