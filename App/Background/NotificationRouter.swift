import UIKit
import UserNotifications

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationRouter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let link = response.notification.request.content.userInfo[BackgroundConstants.deepLinkUserInfoKey] as? String,
              let url = URL(string: link)
        else { return }
        await MainActor.run { UIApplication.shared.open(url) }
    }
}
