import Foundation

@MainActor final class ConnectionNotifier {
    private typealias C = ConnectionNotifierConstants

    private let scheduler: any NotificationScheduling
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    init(
        scheduler: any NotificationScheduling = UserNotificationScheduler(), defaults: UserDefaults = AccountScope.current.defaults,
        calendar: Calendar = .current, now: @escaping () -> Date = { .now }
    ) {
        self.scheduler = scheduler
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    func lost(_ source: ConnectionSource) async {
        let key = C.notifiedKeyPrefix + source.rawValue
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        await scheduler.schedule(
            id: C.idPrefix + source.rawValue, title: ConnectionNotifierText.title(source), text: ConnectionNotifierText.body(source),
            link: DeepLinkConstants.settings, at: QuietHours.deliveryDate(now: now(), calendar: calendar)
        )
    }

    func restored(_ source: ConnectionSource) async {
        let key = C.notifiedKeyPrefix + source.rawValue
        guard defaults.bool(forKey: key) else { return }
        defaults.set(false, forKey: key)
        await scheduler.cancel(id: C.idPrefix + source.rawValue)
    }
}
