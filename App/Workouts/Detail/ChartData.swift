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
            .compactMap { sample in sample.altitude.map { (t: sample.t, meters: $0) } }
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

    static func thinned<Element>(_ items: [Element], limit: Int) -> [Element] {
        guard limit > 0, items.count > limit else { return items }
        let step = Double(items.count - 1) / Double(limit - 1)
        return (0..<limit).map { items[Int((Double($0) * step).rounded())] }
    }
}
