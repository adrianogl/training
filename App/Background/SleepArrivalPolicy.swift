import Foundation

enum SleepArrivalPolicy {
    static func shouldSync(now: Date, calendar: Calendar, readinessComplete: Bool, appActive: Bool, syncing: Bool) -> Bool {
        guard !readinessComplete, !appActive, !syncing else { return false }
        return calendar.component(.hour, from: now) >= BackgroundConstants.refreshHour
    }
}
