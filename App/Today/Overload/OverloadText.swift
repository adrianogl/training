enum OverloadText {
    private typealias C = OverloadConstants

    static func headline(_ alert: OverloadAlert) -> String {
        String(format: C.headlineFormat, alert.days)
    }

    static func flaggedLine(_ alert: OverloadAlert) -> String {
        var parts: [String] = []
        if alert.restingHigh, let now = alert.restingNow, let base = alert.restingBase {
            parts.append(String(format: C.restingLineFormat, now, base))
        }
        if alert.hrvLow, let now = alert.hrvNow, let base = alert.hrvBase {
            parts.append(String(format: C.hrvLineFormat, now, base))
        }
        if alert.loadHigh, let ratio = alert.ratio {
            parts.append(String(format: C.loadLineFormat, TodayText.decimal(ratio, fractionDigits: 1)))
        }
        return parts.joined(separator: " · ")
    }
}
