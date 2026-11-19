import Foundation

enum InstallExpiryConstants {
    static let profileName = "embedded"
    static let profileExtension = "mobileprovision"
    static let plistStart = "<?xml"
    static let plistEnd = "</plist>"
    static let expirationKey = "ExpirationDate"
    static let warningDays = 1
    static let notifyHour = 8
    static let notificationPrefix = "install-expiry-"
    static let deepLink = "training://hoje"
}
