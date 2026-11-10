import Foundation
import Testing
@testable import trAIning

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

    @Test func withoutReadinessRetriesInOneHour() {
        #expect(BackgroundSync.nextBeginDate(after: date(hour: 7), calendar: calendar, readinessComplete: false) == date(hour: 8))
    }

    @Test func withoutReadinessPastCeilingSchedulesTomorrowAtFour() {
        #expect(BackgroundSync.nextBeginDate(after: date(hour: 10, minute: 30), calendar: calendar, readinessComplete: false) == date(hour: 4, day: 11))
    }
}
