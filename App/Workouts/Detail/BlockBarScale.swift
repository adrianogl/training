import FITReader
import Foundation
import WorkoutAnalysis

enum BlockBarScale {
    static func bars(_ blocks: [WorkoutBlock], zones: HeartRateZones?) -> [BlockBar] {
        let raw = blocks.map { block -> (metric: BlockMetric, band: ClosedRange<Double>?, actual: ClosedRange<Double>?) in
            let metric = metric(block)
            return (metric, band(block, metric: metric, zones: zones), actual(block, metric: metric))
        }
        let domains = Dictionary(grouping: raw, by: \.metric).mapValues { items in
            let targeted = items.filter { $0.band != nil }
            let source = targeted.isEmpty ? items : targeted
            return domain(source.flatMap { [$0.band, $0.actual].compactMap { $0 } }, padding: targeted.isEmpty ? WorkoutDetailConstants.barDomainPadding : WorkoutDetailConstants.targetDomainPadding)
        }
        return zip(blocks, raw).map { block, item in
            let domain = domains[item.metric] ?? 0...1
            return BlockBar(
                metric: item.metric,
                band: item.band.map { normalize($0, in: domain) },
                actual: item.actual.map { widen(normalize($0, in: domain)) },
                valueText: valueText(block, metric: item.metric)
            )
        }
    }

    static func bars(_ blocks: [WorkoutBlock], kilometers: BlockKilometers, zones: HeartRateZones?) -> ScaledBars {
        let positions = kilometers.keys.sorted()
        var remaining = bars(blocks + positions.flatMap { kilometers[$0] ?? [] }, zones: zones)[...]
        let blockBars = Array(remaining.prefix(blocks.count))
        remaining = remaining.dropFirst(blocks.count)
        var kilometerBars: [Int: [BlockBar]] = [:]
        for position in positions {
            let count = kilometers[position]?.count ?? 0
            kilometerBars[position] = Array(remaining.prefix(count))
            remaining = remaining.dropFirst(count)
        }
        return ScaledBars(blocks: blockBars, kilometers: kilometerBars)
    }

    private static func metric(_ block: WorkoutBlock) -> BlockMetric {
        switch block.prescribed?.target {
        case .heartRateBpm, .heartRatePercentMax, .heartRateZone: .heartRate
        default: .speed
        }
    }

    private static func band(_ block: WorkoutBlock, metric: BlockMetric, zones: HeartRateZones?) -> ClosedRange<Double>? {
        switch block.prescribed?.target {
        case let .speed(low, high):
            return ordered(low, high)
        case let .heartRateBpm(low, high):
            return ordered(Double(low), Double(high))
        case let .heartRatePercentMax(low, high):
            guard let max = zones?.maxHeartRate else { return nil }
            return ordered(Double(low * max) / 100, Double(high * max) / 100)
        case let .heartRateZone(number):
            guard let floors = zones?.floors, number >= 1, number <= floors.count else { return nil }
            let upper = number < floors.count ? Double(floors[number] - 1) : Double(zones?.maxHeartRate ?? floors[number - 1])
            return ordered(Double(floors[number - 1]), upper)
        default:
            return nil
        }
    }

    private static func actual(_ block: WorkoutBlock, metric: BlockMetric) -> ClosedRange<Double>? {
        let values: [Double]
        switch metric {
        case .speed:
            values = block.laps.compactMap { lap in
                let speed = lap.avgSpeed ?? (lap.timerSeconds > 0 ? lap.distance / lap.timerSeconds : 0)
                return lap.distance > 0 && speed > 0 ? speed : nil
            }
            if values.isEmpty { return block.avgSpeed.map { $0...$0 } }
        case .heartRate:
            values = block.laps.compactMap { $0.avgHeartRate.map(Double.init) }
            if values.isEmpty { return block.avgHeartRate.map { Double($0)...Double($0) } }
        }
        guard let low = values.min(), let high = values.max() else { return nil }
        return low...high
    }

    private static func valueText(_ block: WorkoutBlock, metric: BlockMetric) -> String? {
        switch metric {
        case .speed: WorkoutListModel.paceClock(metersPerSecond: block.avgSpeed)
        case .heartRate: block.avgHeartRate.map { "\($0)" }
        }
    }

    private static func ordered(_ a: Double, _ b: Double) -> ClosedRange<Double>? {
        guard a > 0, b > 0 else { return nil }
        return min(a, b)...max(a, b)
    }

    private static func domain(_ ranges: [ClosedRange<Double>], padding ratio: Double) -> ClosedRange<Double> {
        guard let low = ranges.map(\.lowerBound).min(), let high = ranges.map(\.upperBound).max() else { return 0...1 }
        let span = max(high - low, abs(high) * 0.05, 0.1)
        let padding = span * ratio
        return (low - padding)...(low + span + padding)
    }

    private static func normalize(_ range: ClosedRange<Double>, in domain: ClosedRange<Double>) -> ClosedRange<Double> {
        let width = domain.upperBound - domain.lowerBound
        let low = (range.lowerBound - domain.lowerBound) / width
        let high = (range.upperBound - domain.lowerBound) / width
        return clamp(low)...clamp(high)
    }

    private static func widen(_ range: ClosedRange<Double>) -> ClosedRange<Double> {
        let minimum = WorkoutDetailConstants.barMinimumWidth
        guard range.upperBound - range.lowerBound < minimum else { return range }
        let center = (range.lowerBound + range.upperBound) / 2
        let low = clamp(min(center - minimum / 2, 1 - minimum))
        return low...min(1, low + minimum)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
