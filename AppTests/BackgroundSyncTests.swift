import Foundation
import Storage
import Testing
import TrainingCore
@testable import trAIning

private struct EmptyKeyStore: APIKeyStore {
    func read() throws -> String? { nil }
    func save(_ key: String) throws {}
    func delete() throws {}
}

@MainActor
@Suite struct BackgroundSyncTests {
    private let calendar = Calendar.current

    private func date(hour: Int, minute: Int = 0, day: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    @Test func beforeFourSchedulesTodayAtFour() {
        #expect(BackgroundSync.nextBeginDate(after: date(hour: 1), calendar: calendar, readinessComplete: true) == date(hour: 4))
        #expect(BackgroundSync.nextBeginDate(after: date(hour: 1), calendar: calendar, readinessComplete: false) == date(hour: 4))
    }

    @Test func afterFourWithCompleteReadinessSchedulesTomorrowAtFour() {
        #expect(BackgroundSync.nextBeginDate(after: date(hour: 5), calendar: calendar, readinessComplete: true) == date(hour: 4, day: 11))
    }

    @Test func withoutReadinessRetriesInFifteenMinutes() {
        #expect(BackgroundSync.nextBeginDate(after: date(hour: 7), calendar: calendar, readinessComplete: false) == date(hour: 7, minute: 15))
    }

    @Test func withoutReadinessPastCeilingSchedulesTomorrowAtFour() {
        #expect(BackgroundSync.nextBeginDate(after: date(hour: 10, minute: 50), calendar: calendar, readinessComplete: false) == date(hour: 4, day: 11))
    }

    @Test func backgroundAtFiveThirtyWithoutReadinessRetriesAtFiveFortyFive() {
        #expect(BackgroundSync.nextBeginDate(after: date(hour: 5, minute: 30), calendar: calendar, readinessComplete: false) == date(hour: 5, minute: 45))
    }

    @Test func quickMorningCheckRunsOnlyInTheMorningWindowWithoutReadiness() {
        #expect(MorningQuickCheck.shouldRun(now: date(hour: 8), calendar: calendar, readinessComplete: false))
        #expect(!MorningQuickCheck.shouldRun(now: date(hour: 8), calendar: calendar, readinessComplete: true))
        #expect(!MorningQuickCheck.shouldRun(now: date(hour: 3), calendar: calendar, readinessComplete: false))
        #expect(!MorningQuickCheck.shouldRun(now: date(hour: 11), calendar: calendar, readinessComplete: false))
        #expect(MorningQuickCheck.shouldRun(now: date(hour: 4), calendar: calendar, readinessComplete: false))
    }

    private func modelWithPreviousComplete() throws -> AppModel {
        AppModel(
            container: try TrainingSchema.container(inMemory: true),
            keyStore: EmptyKeyStore(),
            remoteKeyStore: MemoryKeyStore(),
            autoSyncEnabled: false,
            readinessComplete: true,
            readinessDay: Day(year: 2026, month: 11, day: 9),
            today: { Day(year: 2026, month: 11, day: 10) }
        )
    }

    @Test func failedLaunchSyncDoesNotKeepYesterdaysReadiness() async throws {
        let model = try modelWithPreviousComplete()
        let succeeded = await model.syncNow(.launch)
        #expect(!succeeded)
        #expect(!model.todayReadinessComplete)
        let next = BackgroundSync.nextBeginDate(after: date(hour: 5, minute: 30), calendar: calendar, readinessComplete: model.todayReadinessComplete)
        #expect(next == date(hour: 5, minute: 45))
    }

    @Test func failedBackgroundRunWithPreviousCompleteRetriesInFifteenMinutes() async throws {
        let model = try modelWithPreviousComplete()
        let succeeded = await model.syncNow(.background)
        #expect(!succeeded)
        let next = BackgroundSync.nextBeginDate(after: date(hour: 7), calendar: calendar, readinessComplete: model.todayReadinessComplete)
        #expect(next == date(hour: 7, minute: 15))
    }
}
