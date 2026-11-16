import Foundation
import RemoteSync
import Testing
@testable import trAIning

@Suite struct WatchCalendarTests {
    private static let now = Date(timeIntervalSince1970: 1_794_864_600)

    private static func item(_ minutes: Double, _ title: String, allDay: Bool = false, canceled: Bool = false) -> WatchCalendarItem {
        WatchCalendarItem(start: now.addingTimeInterval(minutes * 60), title: title, isAllDay: allDay, isCanceled: canceled)
    }

    @Test func keepsOnlyUpcomingTimedEventsInOrder() {
        let items = [
            Self.item(-30, "GMUD em andamento"),
            Self.item(900, "Refinamento Técnico MEF"),
            Self.item(195, "  Daily MEF  "),
            Self.item(60, "Feriado", allDay: true),
            Self.item(120, "Cancelada", canceled: true),
            Self.item(300, "   "),
        ]

        let events = WatchCalendar.events(items, now: Self.now)

        #expect(events.map(\.title) == ["Daily MEF", "Refinamento Técnico MEF"])
        #expect(events.first?.start == Int(Self.now.timeIntervalSince1970) + 195 * 60)
    }

    @Test func dropsDuplicatesFromTwoCalendarsAndKeepsThree() {
        let items = [
            Self.item(10, "Daily MEF"),
            Self.item(10, "Daily MEF"),
            Self.item(20, "A"),
            Self.item(30, "B"),
            Self.item(40, "C"),
        ]

        #expect(WatchCalendar.events(items, now: Self.now).map(\.title) == ["Daily MEF", "A", "B"])
    }
}
