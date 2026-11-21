import Foundation

enum WorkoutQuickRetry {
    static func shouldRetry(attempt: Int, remaining: TimeInterval) -> Bool {
        attempt < WorkoutNoticeConstants.quickRetryLimit && remaining >= WorkoutNoticeConstants.quickRetryMinimumRemaining
    }
}
