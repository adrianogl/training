import UserNotifications

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationRouter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let link = info[BackgroundConstants.deepLinkUserInfoKey] as? String
        nonisolated(unsafe) let completion = completionHandler
        if let runId = (info[StravaImportConstants.runIdKey] as? NSNumber)?.int64Value,
           [StravaImportConstants.importAction, StravaImportConstants.ignoreAction].contains(response.actionIdentifier) {
            let action = response.actionIdentifier
            Task { @MainActor in
                await StravaNotificationHandler.shared.handle?(action, runId)
                completion()
            }
            return
        }
        MainActor.assumeIsolated {
            if let link, let url = URL(string: link) { DeepLinkCenter.shared.open(url) }
            completion()
        }
    }
}
