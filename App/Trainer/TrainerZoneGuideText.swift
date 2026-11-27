import Foundation
import Insights
import TrainingCore
import WorkoutAnalysis

enum TrainerZoneGuideText {
    private typealias C = TrainerZoneGuideConstants

    static func zoneName(_ zone: Int) -> String {
        "\(ZoneText.short(zone)) \(C.names[zone] ?? "")"
    }

    static func clock(_ seconds: Double) -> String {
        WorkoutFormat.clock(seconds)
    }

    static func change(_ trend: TrainerZoneTrend, at index: Int) -> String {
        guard let delta = TrainerZoneTrends.thresholdChange(trend, at: index) else { return C.changeStart }
        let seconds = Int(delta.rounded())
        guard seconds != 0 else { return C.changeEqual }
        return String(format: C.changeFormat, seconds < 0 ? "−" : "+", abs(seconds))
    }

    static func gap(_ trend: TrainerZoneTrend, at index: Int) -> String? {
        guard let goal = trend.goalThreshold, trend.weeks.indices.contains(index) else { return nil }
        let seconds = Int((trend.weeks[index].threshold - goal).rounded())
        return seconds > 0 ? String(format: C.gapFormat, seconds) : C.onGoal
    }

    static func goalLine(_ goal: Double) -> String {
        String(format: C.goalLine, clock(goal))
    }

    static func paceTarget(_ target: TrainerZoneTarget?) -> String {
        switch (target?.paceLow, target?.paceHigh) {
        case let (low?, high?): "\(clock(min(low, high)))–\(clock(max(low, high)))"
        case let (low?, nil): "> \(clock(low))"
        case let (nil, high?): "< \(clock(high))"
        default: C.empty
        }
    }

    static func heartRateTarget(_ target: TrainerZoneTarget?) -> String {
        switch (target?.heartRateLow, target?.heartRateHigh) {
        case let (low?, high?): "\(low)–\(high)"
        case let (nil, high?): "< \(high + 1)"
        case let (low?, nil): "≥ \(low)"
        default: C.empty
        }
    }

    static func note(_ fit: TrainerZoneFit) -> String? {
        switch fit {
        case .inside: nil
        case .slower(let value): String(format: C.slower, value)
        case .faster(let value): String(format: C.faster, value)
        case .above(let value): String(format: C.above, value)
        case .below(let value): String(format: C.below, value)
        }
    }

    static func rows(_ trend: TrainerZoneTrend, week: TrainerZoneWeek) -> [TrainerZoneRow] {
        C.zones.map { zone in
            let target = week.target(zone)
            let actual = trend.averages[zone]
            let paceNote = both(actual?.pace, target).flatMap { note(TrainerZoneTrends.paceFit($0.0, target: $0.1)) }
            let heartNote = both(actual?.heartRate, target).flatMap { note(TrainerZoneTrends.heartRateFit($0.0, target: $0.1)) }
            return TrainerZoneRow(
                zone: zone, paceTarget: paceTarget(target), pace: actual?.pace.map(clock) ?? C.empty, paceNote: paceNote,
                heartRateTarget: heartRateTarget(target), heartRate: actual?.heartRate.map { "\(Int($0.rounded()))" } ?? C.empty,
                heartRateNote: target?.heartRateLow == nil && target?.heartRateHigh == nil ? nil : heartNote,
                hasPace: actual?.pace != nil, hasHeartRate: actual?.heartRate != nil
            )
        }
    }

    static func bands(_ trend: TrainerZoneTrend, zones: Set<Int>, mode: TrainerZoneChartMode) -> [TrainerZoneChartBand] {
        zones.sorted().flatMap { zone in
            trend.weeks.enumerated().compactMap { index, week -> TrainerZoneChartBand? in
                guard let target = week.target(zone), let range = range(target, mode: mode) else { return nil }
                let ends = [plotted(range.lowerBound, mode: mode), plotted(range.upperBound, mode: mode)]
                return TrainerZoneChartBand(zone: zone, index: index, low: ends.min() ?? 0, high: ends.max() ?? 0)
            }
        }
    }

    static func range(_ target: TrainerZoneTarget, mode: TrainerZoneChartMode) -> ClosedRange<Double>? {
        switch mode {
        case .pace:
            switch (target.paceLow, target.paceHigh) {
            case let (low?, high?): return min(low, high)...max(low, high)
            case let (low?, nil): return low...(low + C.openPaceSeconds)
            case let (nil, high?): return (high - C.openPaceSeconds)...high
            default: return nil
            }
        case .heartRate:
            switch (target.heartRateLow, target.heartRateHigh) {
            case let (low?, high?): return Double(low)...Double(high)
            case let (low?, nil): return Double(low)...Double(low + C.openHeartRate)
            case let (nil, high?): return Double(high - C.openHeartRate)...Double(high)
            default: return nil
            }
        }
    }

    static func points(_ trend: TrainerZoneTrend, zones: Set<Int>, mode: TrainerZoneChartMode) -> [TrainerZoneChartPoint] {
        zones.sorted().flatMap { zone in
            var segment = 0
            var previous: Int?
            return trend.weeks.enumerated().compactMap { index, week -> TrainerZoneChartPoint? in
                let actual = week.actual[zone]
                guard let value = mode == .pace ? actual?.pace : actual?.heartRate else { return nil }
                if let previous, previous != index - 1 { segment += 1 }
                previous = index
                return TrainerZoneChartPoint(zone: zone, index: index, segment: segment, value: plotted(value, mode: mode))
            }
        }
    }

    static func domain(bands: [TrainerZoneChartBand], points: [TrainerZoneChartPoint], goal: Double?, mode: TrainerZoneChartMode) -> ClosedRange<Double> {
        let values = bands.flatMap { [$0.low, $0.high] } + points.map(\.value) + [goal].compactMap { $0 }
        guard let lowest = values.min(), let highest = values.max() else { return 0...1 }
        let padding = mode == .pace ? C.paceAxisPadding : C.heartRateAxisPadding
        let low = ((lowest - padding) / C.axisStep).rounded(.down) * C.axisStep
        let high = ((highest + padding) / C.axisStep).rounded(.up) * C.axisStep
        return low...max(high, low + C.axisStep)
    }

    static func plotted(_ value: Double, mode: TrainerZoneChartMode) -> Double {
        mode == .pace ? -value : value
    }

    static func axisLabel(_ value: Double, mode: TrainerZoneChartMode) -> String {
        mode == .pace ? clock(abs(value)) : "\(Int(value.rounded()))"
    }

    static func monthStarts(_ trend: TrainerZoneTrend) -> [Int] {
        trend.weeks.indices.filter { index in
            index == 0 || trend.weeks[index].start.month != trend.weeks[index - 1].start.month
        }
    }

    static func month(_ day: Day) -> String {
        TrainerConstants.monthShort[day.month - 1]
    }

    static func weekLabel(_ week: TrainerZoneWeek) -> String {
        String(format: C.weekLabel, week.start.day, week.start.month)
    }
}

private func both<A, B>(_ first: A?, _ second: B?) -> (A, B)? {
    guard let first, let second else { return nil }
    return (first, second)
}
