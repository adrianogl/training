import Foundation
import TrainingCore
import UserNotifications

@MainActor final class WatchPendingNotifier {
    private typealias C = WatchPendingNotifierConstants
    private typealias T = WatchPendingNotifierText

    private let scheduler: any NotificationScheduling
    private let inbox: NoticeInboxStore
    private let calendar: Calendar
    private let now: () -> Date

    init(
        scheduler: any NotificationScheduling = NoticeInboxScheduler.standard, inbox: NoticeInboxStore = NoticeInboxStore(),
        calendar: Calendar = .current, now: @escaping () -> Date = { .now }
    ) {
        self.scheduler = scheduler
        self.inbox = inbox
        self.calendar = calendar
        self.now = now
    }

    static func registerCategory() {
        let category = UNNotificationCategory(
            identifier: C.category,
            actions: [UNNotificationAction(identifier: C.sendAction, title: T.sendAction, options: [.foreground])],
            intentIdentifiers: []
        )
        NotificationCategories.register(category)
    }

    func update(tomorrow day: Day, items: [TrainerSendItem], records: [String: TrainerSentRecord], enabled: Bool) async {
        let id = C.idPrefix + day.iso
        let pending = enabled ? items.filter { $0.day == day && TrainerSendBuilder.status($0, records: records) != .current } : []
        guard !pending.isEmpty else {
            await scheduler.cancel(id: id)
            inbox.remove(id: id)
            return
        }
        let current = now()
        guard let date = calendar.date(bySettingHour: C.hour, minute: 0, second: 0, of: current), current < date else { return }
        await scheduler.schedule(
            id: id, title: T.title(pending), text: T.body(pending, records: records), link: C.deepLink, at: date, category: C.category
        )
    }
}
