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
        let content = UNMutableNotificationContent()
        content.body = text
        content.sound = .default
        content.userInfo = [C.deepLinkUserInfoKey: C.readinessDeepLink]
        let trigger = date.map {
            UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0),
                repeats: false
            )
        }
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancel(id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
