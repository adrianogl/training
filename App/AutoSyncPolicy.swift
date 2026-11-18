import Foundation

enum AutoSyncPolicy {
    static func shouldSync(status: SyncStatus, readinessComplete: Bool, now: Date) -> Bool {
        guard readinessComplete, case .finished(let finished) = status else { return true }
        return now.timeIntervalSince(finished) >= AppConstants.autoSyncMinimumInterval
    }
}
