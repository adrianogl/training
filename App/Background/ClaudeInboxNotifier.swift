import Foundation
import Insights

@MainActor final class ClaudeInboxNotifier {
    private let scheduler: any NotificationScheduling
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    init(
        scheduler: any NotificationScheduling = NoticeInboxScheduler.standard, defaults: UserDefaults = AccountScope.current.defaults,
        calendar: Calendar = .current, now: @escaping () -> Date = { .now }
    ) {
        self.scheduler = scheduler
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    func check() async {
        guard let inbox = ClaudeMailbox(defaults: defaults).unseen() else { return }
        if let notified = defaults.object(forKey: ClaudeConstants.inboxNotifiedKey) as? Date, notified >= inbox.savedAt { return }
        defaults.set(inbox.savedAt, forKey: ClaudeConstants.inboxNotifiedKey)
        let count = (try? ClaudeStrengthParser.parse(inbox.json))?.workouts.count ?? 0
        await scheduler.schedule(
            id: ClaudeConstants.inboxNotificationId, title: ClaudeInboxNotifierText.title(count: count), text: ClaudeInboxNotifierText.body,
            link: DeepLinkConstants.trainerStrength, at: QuietHours.deliveryDate(now: now(), calendar: calendar)
        )
    }
}
