import Foundation
import Observation

@MainActor @Observable final class InstallExpiryModel {
    private typealias C = InstallExpiryConstants

    let expiry: Date?

    @ObservationIgnored private let scheduler: any NotificationScheduling
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar

    init(
        expiry: Date? = ProvisioningProfile.expiration(), scheduler: any NotificationScheduling = UserNotificationScheduler(),
        now: @escaping () -> Date = { .now }, calendar: Calendar = .current
    ) {
        self.expiry = expiry
        self.scheduler = scheduler
        self.now = now
        self.calendar = calendar
    }

    var daysLeft: Int? {
        guard let expiry else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now()), to: calendar.startOfDay(for: expiry)).day
    }

    var showsNotice: Bool {
        guard let daysLeft, let expiry else { return false }
        return daysLeft <= C.warningDays && expiry > now()
    }

    var title: String { InstallExpiryText.title(daysLeft: daysLeft ?? 0) }

    var text: String {
        expiry.map { InstallExpiryText.notice(expiry: $0, calendar: calendar) } ?? ""
    }

    func refresh() async {
        for daysBefore in 0...C.warningDays {
            await scheduler.cancel(id: C.notificationPrefix + String(daysBefore))
        }
        guard let expiry else { return }
        let current = now()
        for daysBefore in 0...C.warningDays {
            guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: expiry)),
                  let at = calendar.date(bySettingHour: C.notifyHour, minute: 0, second: 0, of: day),
                  at > current, at < expiry else { continue }
            await scheduler.schedule(
                id: C.notificationPrefix + String(daysBefore), title: InstallExpiryText.title(daysLeft: daysBefore),
                text: InstallExpiryText.notification(expiry: expiry, calendar: calendar), link: C.deepLink, at: at
            )
        }
    }
}
