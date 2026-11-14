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
}
