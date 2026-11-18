import Foundation
import Testing
@testable import trAIning

@Suite struct AutoSyncPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func skipsWhenLastSyncFinishedRecently() {
        #expect(!AutoSyncPolicy.shouldSync(status: .finished(now.addingTimeInterval(-60)), readinessComplete: true, now: now))
        #expect(!AutoSyncPolicy.shouldSync(status: .finished(now.addingTimeInterval(-14 * 60)), readinessComplete: true, now: now))
    }

    @Test func syncsAfterMinimumInterval() {
        #expect(AutoSyncPolicy.shouldSync(status: .finished(now.addingTimeInterval(-15 * 60)), readinessComplete: true, now: now))
    }

    @Test func syncsWhileTodayReadinessIsMissing() {
        #expect(AutoSyncPolicy.shouldSync(status: .finished(now.addingTimeInterval(-60)), readinessComplete: false, now: now))
    }

    @Test func syncsWhenNotFinished() {
        #expect(AutoSyncPolicy.shouldSync(status: .idle, readinessComplete: true, now: now))
        #expect(AutoSyncPolicy.shouldSync(status: .running(progress: 0.5), readinessComplete: true, now: now))
        #expect(AutoSyncPolicy.shouldSync(status: .failed(.missingKey), readinessComplete: true, now: now))
    }
}
