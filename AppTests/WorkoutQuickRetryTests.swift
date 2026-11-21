import Foundation
import Testing
@testable import trAIning

@Suite struct WorkoutQuickRetryTests {
    @Test func retriesWhileBackgroundTimeRemains() {
        #expect(WorkoutQuickRetry.shouldRetry(attempt: 0, remaining: 28))
    }

    @Test func stopsWhenBackgroundTimeIsShort() {
        #expect(!WorkoutQuickRetry.shouldRetry(attempt: 0, remaining: 19))
    }

    @Test func stopsAfterTheAttemptLimitEvenInForeground() {
        #expect(WorkoutQuickRetry.shouldRetry(attempt: WorkoutNoticeConstants.quickRetryLimit - 1, remaining: .greatestFiniteMagnitude))
        #expect(!WorkoutQuickRetry.shouldRetry(attempt: WorkoutNoticeConstants.quickRetryLimit, remaining: .greatestFiniteMagnitude))
    }
}
