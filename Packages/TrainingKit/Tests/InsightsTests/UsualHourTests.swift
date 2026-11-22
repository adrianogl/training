import Foundation
import Testing
@testable import Insights

@Suite struct UsualHourTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func run(_ day: Int, _ hour: Int, km: Double = 8) -> UsualHourRun {
        UsualHourRun(start: date(day, hour), meters: km * 1_000, seconds: km * 330)
    }

    private var now: Date { date(23, 12) }

    private var runs: [UsualHourRun] {
        [run(3, 19), run(5, 20), run(10, 19), run(12, 19), run(17, 20), run(19, 19),
         run(8, 8, km: 18), run(15, 7, km: 20), run(22, 7, km: 21), run(21, 9)]
    }

    @Test func weekdaysAndWeekendsHaveTheirOwnHour() {
        #expect(UsualHour.hour(for: date(24, 6), long: false, runs: runs, now: now, calendar: calendar) == 19)
        #expect(UsualHour.source(for: date(28, 6), long: false, runs: runs, now: now, calendar: calendar).source == .weekend)
    }

    @Test func longRunUsesTheHourOfPastLongRuns() {
        let result = UsualHour.source(for: date(28, 6), long: true, runs: runs, now: now, calendar: calendar)
        #expect(result.hour == 7)
        #expect(result.source == .longRuns)
    }

    @Test func fallsBackToAllRunsAndThenSeven() {
        let weekdayOnly = runs.filter { !calendar.isDateInWeekend($0.start) }
        #expect(UsualHour.source(for: date(28, 6), long: true, runs: weekdayOnly, now: now, calendar: calendar).source == .allRuns)
        #expect(UsualHour.source(for: date(28, 6), long: false, runs: [], now: now, calendar: calendar) == (7, .fallback))
    }

    @Test func ignoresRunsOutsideTheWindow() {
        let old = [run(1, 5), run(2, 5)].map { UsualHourRun(start: $0.start.addingTimeInterval(-60 * 86_400), meters: $0.meters, seconds: $0.seconds) }
        #expect(UsualHour.hour(for: date(24, 6), long: false, runs: old, now: now, calendar: calendar) == 7)
    }
}
