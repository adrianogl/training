import Foundation

enum MorningQuickCheck {
    static func shouldRun(now: Date, calendar: Calendar, readinessComplete: Bool) -> Bool {
        guard !readinessComplete else { return false }
        let hour = calendar.component(.hour, from: now)
        return hour >= BackgroundConstants.refreshHour && hour < BackgroundConstants.retryCeilingHour
    }
}
