import Foundation

public struct Day: Hashable, Comparable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        let components = DateComponents(year: year, month: month, day: day)
        let date = Day.calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        let normalized = Day.calendar.dateComponents([.year, .month, .day], from: date)
        self.year = normalized.year!
        self.month = normalized.month!
        self.day = normalized.day!
    }

    public init?(iso: String) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }
        let candidate = Day(year: year, month: month, day: day)
        guard candidate.year == year, candidate.month == month, candidate.day == day else { return nil }
        self = candidate
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = Day(iso: value) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Data inválida: \(value)")
            )
        }
        self = parsed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }

    public var iso: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public func adding(days: Int) -> Day {
        let date = Day.calendar.date(byAdding: .day, value: days, to: startDate)!
        let components = Day.calendar.dateComponents([.year, .month, .day], from: date)
        return Day(year: components.year!, month: components.month!, day: components.day!)
    }

    public func days(until other: Day) -> Int {
        Day.calendar.dateComponents([.day], from: startDate, to: other.startDate).day!
    }

    public static func today(in timeZone: TimeZone = .current, now: Date = .now) -> Day {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        return Day(year: components.year!, month: components.month!, day: components.day!)
    }

    public var weekStart: Day {
        let weekday = Day.calendar.component(.weekday, from: startDate)
        let offsetFromMonday = (weekday + 5) % 7
        return adding(days: -offsetFromMonday)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private var startDate: Date {
        Day.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()
}
