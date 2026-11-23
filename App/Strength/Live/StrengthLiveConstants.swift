import Foundation

enum StrengthLiveConstants {
    static let sessionFile = "strength-live-session.json"
    static let plansFile = "strength-live-plans-v2.json"
    static let plansKeptDays = 3
    static let staleAfter: TimeInterval = 4 * 60 * 60
    static let uploadWindow: TimeInterval = 24 * 60 * 60
    static let activitiesQuery = "?start=0&limit=10"
    static let noticeSeconds: Duration = .seconds(4)
    static let highlightSeconds: Duration = .seconds(2)
    static let commandTimeout: Duration = .seconds(8)
    static let uploadRetries: [Duration] = [.seconds(60), .seconds(120), .seconds(300)]
}

enum StrengthLiveViewConstants {
    static let titleSize: CGFloat = 32
    static let statSize: CGFloat = 22
    static let restSize: CGFloat = 28
    static let doneSize: CGFloat = 17
    static let planSize: CGFloat = 15
    static let numberWidth: CGFloat = 36
    static let markerWidth: CGFloat = 22
    static let lastWidth: CGFloat = 64
    static let barHeight: CGFloat = 5
    static let rowPadding: CGFloat = 8
    static let restBoxOpacity: Double = 0.12
    static let pendingOpacity: Double = 0.55
    static let cardSpacing: CGFloat = 12
    static let check = "✓"
    static let sheetHeight: CGFloat = 260
    static let toastBottom: CGFloat = 96
    static let highlightOpacity: Double = 0.18
    static let later = "↻"
}
