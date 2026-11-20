import Foundation

enum QuietHours {
    static let startHour = 22
    static let endHour = 7

    static func deliveryDate(now: Date, calendar: Calendar) -> Date? {
        let hour = calendar.component(.hour, from: now)
        guard hour >= startHour || hour < endHour else { return nil }
        let day = hour >= startHour ? calendar.date(byAdding: .day, value: 1, to: now) ?? now : now
        return calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: day)
    }
}
