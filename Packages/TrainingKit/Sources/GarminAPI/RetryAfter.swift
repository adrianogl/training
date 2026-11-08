import Foundation

enum RetryAfter {
    static func seconds(from header: String?, now: Date) -> Int? {
        guard let value = header?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = Int(value) {
            return clamped(seconds)
        }
        guard let date = httpDate(value) else { return nil }
        return clamped(Int(date.timeIntervalSince(now).rounded(.up)))
    }

    private static func clamped(_ seconds: Int) -> Int {
        min(max(seconds, 0), GarminEndpoints.maxRetryAfterSeconds)
    }

    private static func httpDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = GarminEndpoints.httpDateFormat
        return formatter.date(from: value)
    }
}
