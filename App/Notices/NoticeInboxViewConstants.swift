import CoreGraphics
import Foundation

enum NoticeInboxViewConstants {
    static let bellSymbol = "bell"
    static let bellTapSize: CGFloat = 44
    static let bellDotSize: CGFloat = 9
    static let bellDotInset: CGFloat = 9
    static let bellDotOutline: CGFloat = 1.5
    static let closeSymbol = "xmark"
    static let garminSymbol = "watch.analog"
    static let dotSize: CGFloat = 8
    static let rowSpacing: CGFloat = 12
    static let rowVerticalPadding: CGFloat = 10
    static let rowDividerInset: CGFloat = 42
    static let cardSpacing: CGFloat = 9
    static let titleDotSpacing: CGFloat = 7
    static let iconSymbolSize: CGFloat = 15
    static let iconSize: CGFloat = 30
    static let toneFillOpacity = 0.16
    static let planLink = DeepLinkConstants.trainerChanges
    static let locale = Locale(identifier: "pt_BR")
    static let recentDays = 6
    static let defaultIcon = NoticeIcon(linkPrefix: "", symbol: "bell", tone: .neutral)
    static let icons = [
        NoticeIcon(linkPrefix: DeepLinkConstants.trainerChanges, symbol: "calendar", tone: .neutral),
        NoticeIcon(linkPrefix: DeepLinkConstants.trainerStrength, symbol: "dumbbell", tone: .neutral),
        NoticeIcon(linkPrefix: BackgroundConstants.readinessDeepLink, symbol: "waveform.path.ecg", tone: .neutral),
        NoticeIcon(linkPrefix: DeepLinkConstants.settings, symbol: "exclamationmark.triangle", tone: .danger),
        NoticeIcon(linkPrefix: DeepLinkConstants.workoutsPrefix, symbol: "star", tone: .record),
        NoticeIcon(linkPrefix: StrengthConstants.recordLink, symbol: "trophy", tone: .record),
        NoticeIcon(linkPrefix: StravaImportConstants.workoutsLink, symbol: "figure.run", tone: .neutral),
        NoticeIcon(linkPrefix: RaceNoticeConstants.link, symbol: "flag", tone: .race),
    ]
}
