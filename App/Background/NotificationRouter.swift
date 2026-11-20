import UserNotifications

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationRouter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let link = response.notification.request.content.userInfo[BackgroundConstants.deepLinkUserInfoKey] as? String
        nonisolated(unsafe) let completion = completionHandler
        MainActor.assumeIsolated {
            if let link, let url = URL(string: link) { DeepLinkCenter.shared.open(url) }
            completion()
        }
    }
}
