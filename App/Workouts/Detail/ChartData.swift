import TrainingCore
import FITReader
import Foundation
import WorkoutAnalysis

enum ChartData {
    static func heartRateSeries(_ samples: [FITSample]) -> [(t: Double, bpm: Int)] {
        samples
            .sorted { $0.t < $1.t }
            .compactMap { sample in sample.heartRate.flatMap { $0 > 0 ? (t: sample.t, bpm: $0) : nil } }
    }

    static func altitudeSeries(_ samples: [FITSample]) -> [(t: Double, meters: Double)] {
        samples
            .sorted { $0.t < $1.t }
            .compactMap { sample in sample.altitude.flatMap { $0.isFinite ? (t: sample.t, meters: $0) : nil } }
    }

    static func zoneShares(_ zoneSeconds: [Double]) -> [Double] {
        let clean = zoneSeconds.map { $0.isFinite ? max(0, $0) : 0 }
        let total = clean.reduce(0, +)
        guard total > 0 else { return clean.map { _ in 0 } }
        return clean.map { $0 / total }
    }

    static func zoneBands(_ zones: HeartRateZones?, ceiling: Double) -> [ZoneBand] {
        guard let floors = zones?.floors, !floors.isEmpty else { return [] }
        let top = max(ceiling, Double(zones?.maxHeartRate ?? 0), Double(floors.last ?? 0))
        return floors.enumerated().map { index, floor in
            let high = index + 1 < floors.count ? Double(floors[index + 1]) : top
            return ZoneBand(zone: index + 1, low: Double(floor), high: high)
        }
    }

    static func activeSpans(_ blocks: [WorkoutBlock]) -> [BlockSpan] {
        blocks.filter { $0.kind == .active }.flatMap { block in
            block.laps.compactMap { lap in
                lap.timerSeconds > 0 ? BlockSpan(start: lap.startOffset, end: lap.startOffset + lap.timerSeconds) : nil
            }
        }
    }

    static func thinned<Element>(_ items: [Element], limit: Int, value: (Element) -> Double) -> [Element] {
        guard limit >= 2, items.count > limit else { return items }
        let buckets = limit / 2
        let size = Double(items.count) / Double(buckets)
        var result: [Element] = []
        result.reserveCapacity(buckets * 2)
        for bucket in 0..<buckets {
            let lower = Int((Double(bucket) * size).rounded(.down))
            let upper = min(items.count, Int((Double(bucket + 1) * size).rounded(.down)))
            guard lower < upper else { continue }
            var low = lower
            var high = lower
            for index in lower..<upper {
                if value(items[index]) < value(items[low]) { low = index }
                if value(items[index]) > value(items[high]) { high = index }
            }
            result.append(items[min(low, high)])
            if low != high { result.append(items[max(low, high)]) }
        }
        return result
    }

    static func routePoints(_ route: [Coordinate]) -> [Coordinate] {
        route.filter { point in
            point.lat.isFinite && point.lon.isFinite
                && abs(point.lat) <= 90 && abs(point.lon) <= 180
                && !(point.lat == 0 && point.lon == 0)
        }
    }
}
