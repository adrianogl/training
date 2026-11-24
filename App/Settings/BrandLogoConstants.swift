import Foundation

enum BrandLogoConstants {
    static let directory = "BrandLogos"
    static let fileExtension = "png"
    static let files: [SettingsGroup: String] = [
        .garmin: "garmin",
        .mfit: "mfit",
        .strava: "strava",
        .claude: "claude",
    ]
}
