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
    static let openActivityDefaultsKey = "openActivity"
    static let detailScrollDefaultsKey = "detailScroll"
    static let openShareDefaultsKey = "openShare"
    static let exportShareDefaultsKey = "exportShare"
    static let createKeyURL = URL(string: "https://connect.garmin.com/app/settings/personalApiToken")!
}
