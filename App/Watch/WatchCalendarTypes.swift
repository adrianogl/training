import Foundation

struct WatchCalendarItem: Equatable {
    let start: Date
    let title: String
    let isAllDay: Bool
    let isCanceled: Bool
}
