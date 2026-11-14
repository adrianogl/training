import Foundation
import TrainingCore

enum OverloadDetector {
    private typealias C = OverloadConstants

    static func alert(_ signals: [DailySignal], today: Day, ratio: Double?) -> OverloadAlert? {
        let recentStart = today.adding(days: -(C.recentDays - 1))
        let baseStart = recentStart.adding(days: -C.baselineDays)
        let recent = signals.filter { $0.day >= recentStart && $0.day <= today }
        let base = signals.filter { $0.day >= baseStart && $0.day < recentStart }
        guard recent.count == C.recentDays else { return nil }
        let restingBase = median(base.compactMap(\.restingHeartRate).map(Double.init))
        let hrvBase = median(base.compactMap(\.hrv))
        let restingHigh = restingBase.map { baseValue in
            recent.allSatisfy { ($0.restingHeartRate.map(Double.init) ?? 0) >= baseValue + Double(C.restingMargin) }
        } ?? false
        let hrvLow = hrvBase.map { baseValue in
            recent.allSatisfy { ($0.hrv ?? .infinity) <= baseValue * C.hrvShare }
        } ?? false
        let loadHigh = (ratio ?? 0) >= C.highRatio
        guard (restingHigh && hrvLow) || ((restingHigh || hrvLow) && loadHigh) else { return nil }
        let latest = recent.max { $0.day < $1.day }
        return OverloadAlert(
            days: C.recentDays,
            restingNow: latest?.restingHeartRate,
            restingBase: restingBase.map { Int($0.rounded()) },
            hrvNow: latest?.hrv.map { Int($0.rounded()) },
            hrvBase: hrvBase.map { Int($0.rounded()) },
            ratio: ratio,
            restingHigh: restingHigh,
            hrvLow: hrvLow,
            loadHigh: loadHigh
        )
    }

    private static func median(_ values: [Double]) -> Double? {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
