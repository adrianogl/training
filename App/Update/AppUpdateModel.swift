import Foundation
import Observation

@MainActor @Observable final class AppUpdateModel {
    private typealias C = AppUpdateConstants

    private(set) var update: AppUpdate?
    private(set) var dismissedDay: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let installed: String
    @ObservationIgnored private let scheduler: any NotificationScheduling
    @ObservationIgnored private let fetch: @Sendable (URL) async throws -> Data
    @ObservationIgnored private let url: URL
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard, installed: String = AppBuildInfo().version,
        scheduler: any NotificationScheduling = UserNotificationScheduler(),
        fetch: @escaping @Sendable (URL) async throws -> Data = { try await URLSession.shared.data(from: $0).0 },
        url: URL = AppConstants.remoteSyncBaseURL.appending(path: AppUpdateConstants.filePath),
        now: @escaping () -> Date = { .now }, calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.installed = installed
        self.scheduler = scheduler
        self.fetch = fetch
        self.url = url
        self.now = now
        self.calendar = calendar
        dismissedDay = defaults.string(forKey: C.dismissedDayDefaultsKey)
        update = cachedRelease().flatMap { AppVersion.update(for: $0, installed: installed) }
    }

    var showsNotice: Bool {
        update != nil && dismissedDay != dayKey(now())
    }

    func refresh(force: Bool = false) async {
        let current = now()
        if !force, let last = defaults.object(forKey: C.lastCheckDefaultsKey) as? Date, current.timeIntervalSince(last) < C.checkInterval {
            await syncNotification()
            return
        }
        guard let data = try? await fetch(url), let release = try? JSONDecoder().decode(AppRelease.self, from: data) else { return }
        defaults.set(data, forKey: C.releaseDefaultsKey)
        defaults.set(current, forKey: C.lastCheckDefaultsKey)
        update = AppVersion.update(for: release, installed: installed)
        await syncNotification()
    }

    func dismiss() {
        let day = dayKey(now())
        dismissedDay = day
        defaults.set(day, forKey: C.dismissedDayDefaultsKey)
    }

    func syncNotification() async {
        guard let update else {
            await scheduler.cancel(id: C.notificationId)
            return
        }
        await scheduler.scheduleDaily(
            id: C.notificationId, title: AppUpdateText.title(update), text: AppUpdateText.body(update), link: C.deepLink, hour: C.notifyHour
        )
    }

    private func cachedRelease() -> AppRelease? {
        defaults.data(forKey: C.releaseDefaultsKey).flatMap { try? JSONDecoder().decode(AppRelease.self, from: $0) }
    }

    private func dayKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
