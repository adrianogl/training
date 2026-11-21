import Foundation
import Testing
@testable import trAIning

@Suite struct SleepArrivalPolicyTests {
    private let calendar = Calendar.current

    private func at(hour: Int, minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: calendar.startOfDay(for: .now))!
    }

    @Test func syncsWhenSleepArrivesInTheMorningWithoutReadiness() {
        #expect(SleepArrivalPolicy.shouldSync(now: at(hour: 9, minute: 5), calendar: calendar, readinessComplete: false, appActive: false, syncing: false))
    }

    @Test func syncsLateMorningAfterTheRefreshCeiling() {
        #expect(SleepArrivalPolicy.shouldSync(now: at(hour: 11, minute: 30), calendar: calendar, readinessComplete: false, appActive: false, syncing: false))
    }

    @Test func skipsWhenReadinessAlreadyComplete() {
        #expect(!SleepArrivalPolicy.shouldSync(now: at(hour: 9), calendar: calendar, readinessComplete: true, appActive: false, syncing: false))
    }

    @Test func skipsWhileTheAppIsOnScreen() {
        #expect(!SleepArrivalPolicy.shouldSync(now: at(hour: 9), calendar: calendar, readinessComplete: false, appActive: true, syncing: false))
    }

    @Test func skipsWhileAnotherArrivalIsSyncing() {
        #expect(!SleepArrivalPolicy.shouldSync(now: at(hour: 9), calendar: calendar, readinessComplete: false, appActive: false, syncing: true))
    }

    @Test func skipsBeforeTheMorningRefreshHour() {
        #expect(!SleepArrivalPolicy.shouldSync(now: at(hour: 3, minute: 59), calendar: calendar, readinessComplete: false, appActive: false, syncing: false))
    }
}
