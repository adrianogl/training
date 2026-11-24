import Foundation
import UserNotifications

struct UserNotificationScheduler: NotificationScheduling {
    private typealias C = BackgroundConstants

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func pending() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func schedule(id: String, text: String, at date: Date?) async {
        await schedule(id: id, title: nil, text: text, link: C.readinessDeepLink, at: date)
    }

    func schedule(id: String, title: String?, text: String, link: String, at date: Date?) async {
        await schedule(id: id, title: title, text: text, link: link, at: date, category: nil)
    }

    func schedule(id: String, title: String?, text: String, link: String, at date: Date?, category: String?) async {
        let content = UNMutableNotificationContent()
        if let title { content.title = title }
        if let category { content.categoryIdentifier = category }
        content.body = text
        content.sound = .default
        content.userInfo = [C.deepLinkUserInfoKey: link]
        let trigger = date.map {
            UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0),
                repeats: false
            )
        }
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func scheduleDaily(id: String, title: String, text: String, link: String, hour: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = text
        content.sound = .default
        content.userInfo = [C.deepLinkUserInfoKey: link]
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
