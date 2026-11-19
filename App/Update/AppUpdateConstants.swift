import Foundation

enum AppUpdateConstants {
    static let filePath = "versao.json"
    static let checkInterval: TimeInterval = 6 * 60 * 60
    static let notifyHour = 8
    static let notificationId = "app-update"
    static let deepLink = "training://hoje"
    static let releaseDefaultsKey = "appUpdate.release"
    static let lastCheckDefaultsKey = "appUpdate.lastCheck"
    static let dismissedDayDefaultsKey = "appUpdate.dismissedDay"
    static let maxNotes = 3
}
