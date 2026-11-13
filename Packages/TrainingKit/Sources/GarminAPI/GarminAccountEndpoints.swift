import Foundation

public enum GarminAccountEndpoints {
    public static let loginURL = URL(string: "https://sso.garmin.com/mobile/api/login")!
    public static let mfaURL = URL(string: "https://sso.garmin.com/mobile/api/mfa/verifyCode")!
    public static let tokenURL = URL(string: "https://diauth.garmin.com/di-oauth2-service/oauth/token")!
    public static let apiBase = URL(string: "https://connectapi.garmin.com")!
    public static let ssoOrigin = "https://sso.garmin.com"
    public static let ssoClientId = "GCM_IOS_DARK"
    public static let serviceURL = "https://mobile.integration.garmin.com/gcm/ios"
    public static let locale = "en-US"
    public static let loginUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    public static let serviceTicketGrant = "https://connectapi.garmin.com/di-oauth2-service/oauth/grant/service_ticket"
    public static let refreshGrant = "refresh_token"
    public static let clientIds = [
        "GARMIN_CONNECT_MOBILE_ANDROID_DI_2025Q2",
        "GARMIN_CONNECT_MOBILE_ANDROID_DI_2024Q4",
        "GARMIN_CONNECT_MOBILE_ANDROID_DI",
        "GARMIN_CONNECT_MOBILE_IOS_DI",
    ]
    public static let nativeHeaders = [
        "User-Agent": "GCM-Android-5.23",
        "X-Garmin-User-Agent": "com.garmin.android.apps.connectmobile/5.23; ; Google/sdk_gphone64_arm64/google; Android/33; Dalvik/2.1.0",
        "X-Garmin-Paired-App-Version": "10861",
        "X-Garmin-Client-Platform": "Android",
        "X-App-Ver": "10861",
        "X-Lang": "en",
        "X-GCExperience": "GC5",
        "Accept-Language": "en-US,en;q=0.9",
    ]
    public static let refreshMargin: TimeInterval = 900
    public static let defaultMFAMethod = "email"
    public static let successStatus = "SUCCESSFUL"
    public static let mfaStatus = "MFA_REQUIRED"
    public static let invalidCredentialsStatus = "INVALID_USERNAME_PASSWORD"
    public static let calendarPathFormat = "/calendar-service/year/%d/month/%d"
    public static let coursesPath = "/course-service/course"
    public static let workoutPathPrefix = "/workout-service/workout/"
}
