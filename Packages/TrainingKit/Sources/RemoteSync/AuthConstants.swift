enum AuthConstants {
    static let signupPath = "api/v1/auth/signup"
    static let loginPath = "api/v1/auth/login"
    static let logoutPath = "api/v1/auth/logout"
    static let mePath = "api/v1/auth/me"
    static let passwordPath = "api/v1/auth/password"
    static let forgotPath = "api/v1/auth/forgot"
    static let resetPath = "api/v1/auth/reset"
    static let verifyPath = "api/v1/auth/verify"
    static let resendVerificationPath = "api/v1/auth/resend-verification"
    static let sessionsPath = "api/v1/auth/sessions"
    static let accountPath = "api/v1/account"
    static let invitePreviewPath = "api/v1/invites/preview"
    static let inviteQuery = "c"
    static let sessionIdQuery = "id"
    static let passwordMinLength = 10
    static let clientHeader = "X-Training-Client"
    static let clientValue = "app"
}
