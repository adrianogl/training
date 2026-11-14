import Foundation

enum WorkoutNoticeConstants {
    static let enabledKey = "workoutNoticeEnabled"
    static let permissionRequestedKey = "workoutNoticePermissionRequested"
    static let anchorKey = "workoutNoticeAnchor"
    static let notifiedKey = "workoutNoticeNotifiedIds"
    static let defaultEnabled = true
    static let recentWindow: TimeInterval = 6 * 60 * 60
    static let matchTolerance: TimeInterval = 10 * 60
    static let notifiedLimit = 30
    static let idPrefix = "workout-finished-"
    static let deepLink = "training://treinos"
    static let titleScoreFormat = "%@ · nota %d"
    static let fallbackName = "Corrida"
    static let statsFormat = "%@ km · %@/km"
    static let heartRateFormat = " · FC média %d"
    static let metTitleFormat = "Meta cumprida · %@ · %@"
    static let pauseOne = "Teve 1 pausa."
    static let pausesFormat = "Teve %d pausas."
    static let pauseNoteFormat = "%@ Maior trecho contínuo: %@ km. A meta é %@ km sem pausas."
    static let longNearShare = 0.7
    static let timeMatchLow = 0.99
    static let timeMatchHigh = 1.05
}
