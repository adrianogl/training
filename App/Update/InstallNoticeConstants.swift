import Foundation

enum InstallNoticeConstants {
    static let versionDefaultsKey = "installNotice.version"
    static let expiryDefaultsKey = "installNotice.expiry"
    static let cardDefaultsKey = "installNotice.card"
    static let notificationId = "app-installed"
    static let maxNotes = 3
    static let settleDelay = Duration.seconds(2)
}
