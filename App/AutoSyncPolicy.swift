import Foundation

enum AutoSyncPolicy {
    static func shouldSync(status: SyncStatus, now: Date) -> Bool {
        guard case .finished(let finished) = status else { return true }
        return now.timeIntervalSince(finished) >= AppConstants.autoSyncMinimumInterval
    }
}
