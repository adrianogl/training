import Foundation

enum BackgroundConstants {
    static let refreshTaskId = "dev.aglv.training.refresh"
    static let refreshHour = 4
    static let retryInterval: TimeInterval = 60 * 60
    static let retryCeilingHour = 11
    static let notificationIdPrefix = "morning-readiness-"
    static let readinessDeepLink = "training://hoje/prontidao"
    static let deepLinkUserInfoKey = "url"
    static let noticeEnabledDefaultsKey = "morningNoticeEnabled"
    static let noticeMinimumMinutesDefaultsKey = "morningNoticeMinimumMinutes"
    static let notifiedDayDefaultsKey = "morningNoticeNotifiedDay"
    static let readyDayDefaultsKey = "morningNoticeReadyDay"
    static let readyAtDefaultsKey = "morningNoticeReadyAt"
    static let lastAppOpenDefaultsKey = "lastAppOpen"
    static let permissionRequestedDefaultsKey = "morningNoticePermissionRequested"
    static let defaultNoticeEnabled = true
    static let defaultMinimumMinutes = 6 * 60
    static let minutesPerHour = 60
}
