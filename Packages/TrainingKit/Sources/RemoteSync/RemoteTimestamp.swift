import Foundation

public enum RemoteTimestamp {
    public static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    public static func string(from date: Date) -> String {
        let total = milliseconds(date)
        let seconds = total.quotient(dividingBy: 1_000)
        let fraction = total - seconds * 1_000
        let base = Date(timeIntervalSince1970: TimeInterval(seconds)).formatted(.iso8601)
        return "\(base.dropLast()).\(String(format: "%03lld", fraction))Z"
    }

    public static func date(from text: String) -> Date? {
        guard text.hasSuffix("Z") else { return nil }
        let body = text.dropLast()
        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), let whole = try? Date("\(parts[0])Z", strategy: .iso8601) else { return nil }
        var millis: Int64 = 0
        if parts.count == 2 {
            let digits = parts[1]
            guard (1...9).contains(digits.count), digits.allSatisfy(\.isASCII), let value = Int64(digits.prefix(3).padding(toLength: 3, withPad: "0", startingAt: 0)) else { return nil }
            millis = value
        }
        let total = milliseconds(whole) + millis
        return Date(timeIntervalSince1970: TimeInterval(total) / 1_000)
    }
}

private extension Int64 {
    func quotient(dividingBy divisor: Int64) -> Int64 {
        self >= 0 ? self / divisor : (self - divisor + 1) / divisor
    }
}
