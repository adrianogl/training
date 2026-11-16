import EventKit
import Foundation
import RemoteSync

enum WatchCalendar {
    private typealias C = WatchCalendarConstants

    static var status: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    static func requestAccess() async -> Bool {
        (try? await EKEventStore().requestFullAccessToEvents()) ?? false
    }

    static func upcoming(now: Date) -> [WatchEvent] {
        guard status == .fullAccess else { return [] }
        let store = EKEventStore()
        let predicate = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(C.windowSeconds), calendars: nil)
        let items = store.events(matching: predicate).map { event in
            WatchCalendarItem(start: event.startDate, title: event.title ?? "", isAllDay: event.isAllDay, isCanceled: event.status == .canceled)
        }
        return events(items, now: now)
    }

    static func events(_ items: [WatchCalendarItem], now: Date) -> [WatchEvent] {
        var seen = Set<String>()
        return items
            .filter { !$0.isAllDay && !$0.isCanceled && $0.start > now }
            .sorted { $0.start < $1.start }
            .compactMap { item -> WatchEvent? in
                let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let start = Int(item.start.timeIntervalSince1970)
                guard !title.isEmpty, seen.insert("\(start)|\(title)").inserted else { return nil }
                return WatchEvent(start: start, title: title)
            }
            .prefix(C.maxEvents)
            .map { $0 }
    }
}
