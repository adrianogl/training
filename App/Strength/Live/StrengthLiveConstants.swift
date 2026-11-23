import Foundation

enum StrengthLiveConstants {
    static let sessionFile = "strength-live-session.json"
    static let plansFile = "strength-live-plans.json"
    static let staleAfter: TimeInterval = 4 * 60 * 60
}

enum StrengthLiveViewConstants {
    static let titleSize: CGFloat = 32
    static let statSize: CGFloat = 22
    static let restSize: CGFloat = 28
    static let doneSize: CGFloat = 17
    static let planSize: CGFloat = 15
    static let numberWidth: CGFloat = 36
    static let lastWidth: CGFloat = 64
    static let barHeight: CGFloat = 5
    static let rowPadding: CGFloat = 8
    static let restBoxOpacity: Double = 0.12
    static let pendingOpacity: Double = 0.55
    static let cardSpacing: CGFloat = 12
    static let check = "✓"
    static let later = "↻"
}
