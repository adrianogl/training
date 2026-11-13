import Foundation

enum AppConstants {
    static let storeFileName = "store.sqlite"
    static let keychainService = "dev.aglv.training"
    static let keychainAccount = "garmin-personal-api-key"
    static let apiKeyEnvironmentVariable = "TRAINING_API_KEY"
    static let testHostEnvironmentVariable = "TRAINING_TEST_HOST"
    static let launchFITLimit = 25
    static let narrativeBackfillLimit = 10
    static let narrativeScanLimit = 30
    static let urlScheme = "training"
    static let readinessDeepLinkPath = "/prontidao"
    static let initialSectionDefaultsKey = "initialSection"
    static let openTodayDefaultsKey = "openToday"
    static let todayScrollDefaultsKey = "todayScroll"
    static let openMetricDefaultsKey = "openMetric"
    static let evolutionScrollDefaultsKey = "evolutionScroll"
    static let evolutionHorizonDefaultsKey = "evolutionHorizon"
    static let openActivityDefaultsKey = "openActivity"
    static let detailScrollDefaultsKey = "detailScroll"
    static let openRaceDefaultsKey = "openRace"
    static let raceScrollDefaultsKey = "raceScroll"
    static let settingsScrollDefaultsKey = "settingsScroll"
    static let openShareDefaultsKey = "openShare"
    static let exportShareDefaultsKey = "exportShare"
    static let appearanceDefaultsKey = "appearance"
    static let weeklyGoalDefaultsKey = "weeklyGoalKm"
    static let plannedWeeksDefaultsKey = "plannedWeeklyKmFromSteps"
    static let weeklyGoalRange = 0...200
    static let weeklyGoalStep = 5
    static let settingsListWidth: Double = 320
    static let settingsIconSize: Double = 30
    static let sidebarCollapsedSections: Set<AppSection> = [.workouts, .races, .settings]
    static let introDuration = Duration.milliseconds(1700)
    static let introReducedMotionDuration = Duration.milliseconds(500)
    static let introFadeSeconds = 0.35
    static let remoteSyncKeychainAccount = "remote-sync-key"
    static let watchTokenKeychainAccount = "watch-token"
    static let garminSessionKeychainAccount = "garmin-account-session"
    static let watchReadinessDefaultsKey = "watchReadinessLastSent"
    static let remoteSyncBaseURL = URL(string: "https://training-sync-ashy.vercel.app")!
    static let remoteSyncURLEnvironmentVariable = "TRAINING_SYNC_URL"
    static let remoteSyncDebounce = Duration.seconds(2)
    static let createKeyURL = URL(string: "https://connect.garmin.com/app/settings/personalApiToken")!
}
