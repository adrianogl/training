import Foundation
import HealthKit
import os

enum WorkoutNoticeConstants {
    static let enabledKey = "workoutNoticeEnabled"
    static let permissionRequestedKey = "workoutNoticePermissionRequested.wake"
    static let enabledAtKey = "workoutNoticeEnabledAt"
    static let notifiedKey = "workoutNoticeNotifiedIds"
    static let notifiedWorkoutsKey = "workoutNoticeNotifiedWorkouts"
    static let pendingKey = "workoutNoticePending"
    static let logger = Logger(subsystem: "trAIning", category: "WorkoutNotice")
    static let backgroundTaskName = "workout-notice"
    static let retryDelay: TimeInterval = 5 * 60
    static let quickRetryDelay: Duration = .seconds(15)
    static let quickRetryLimit = 6
    static let quickRetryMinimumRemaining: TimeInterval = 20
    static let wakeTypes: [HKQuantityTypeIdentifier] = [.heartRate, .distanceWalkingRunning, .activeEnergyBurned]
    static let defaultEnabled = true
    static let recentWindow: TimeInterval = 6 * 60 * 60
    static let matchTolerance: TimeInterval = 10 * 60
    static let notifiedLimit = 30
    static let idPrefix = "workout-finished-"
    static let titleScoreFormat = "%@ · nota %d"
    static let fallbackName = "Corrida"
    static let statsFormat = "%@ km · %@/km"
    static let heartRateFormat = " · FC média %d"
    static let metTitleFormat = "Meta cumprida · %@ · %@"
    static let highlightSeparator = " · "
    static let highlightBodySeparator = " "
    static let pauseOne = "Teve 1 pausa."
    static let pausesFormat = "Teve %d pausas."
    static let pauseNoteFormat = "%@ Maior trecho contínuo: %@ km. A meta é %@ km sem pausas."
    static let longNearShare = 0.7
    static let timeMatchLow = 0.99
    static let timeMatchHigh = 1.05
}
