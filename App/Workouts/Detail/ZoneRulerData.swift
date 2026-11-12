import Foundation
import Metrics
import TrainingCore
import WorkoutAnalysis

extension ZoneRulerData {
    static func make(
        activityFloors: [Int] = [],
        watchZones: HeartRateZones?,
        watchSeconds: [Double],
        thresholdHeartRate: Int?,
        thresholdSeconds: [Double]
    ) -> ZoneRulerData? {
        let floors = activityFloors.count == WorkoutDetailConstants.zoneCount ? activityFloors : watchZones?.floors ?? []
        guard floors.count == WorkoutDetailConstants.zoneCount else { return nil }
        let watch = ZoneBar(floors: floors, seconds: Array(watchSeconds.prefix(WorkoutDetailConstants.zoneCount)))
        let threshold = thresholdHeartRate.flatMap { heartRate in
            thresholdSeconds.isEmpty ? nil : ZoneBar(floors: thresholdZones(thresholdHeartRate: heartRate).floors, seconds: thresholdSeconds)
        }
        guard watch.hasTime || threshold != nil else { return nil }
        return ZoneRulerData(
            watch: watch,
            threshold: threshold,
            divergence: zoneDivergence(watchZone5Floor: floors.last, thresholdHeartRate: thresholdHeartRate),
            thresholdHeartRate: thresholdHeartRate
        )
    }

    var range: ClosedRange<Int> {
        let floors = (watch.floors + (threshold?.floors ?? [])).filter { $0 > 0 }
        let top = max(watch.floors.last ?? 0, thresholdHeartRate ?? 0) + WorkoutDetailConstants.rulerTopMargin
        let lower = min(WorkoutDetailConstants.rulerRange.lowerBound, floors.min() ?? WorkoutDetailConstants.rulerRange.lowerBound)
        return lower...max(WorkoutDetailConstants.rulerRange.upperBound, top)
    }

    var thresholdTitle: String? {
        guard threshold != nil, let thresholdHeartRate else { return nil }
        return String(format: WorkoutDetailConstants.rulerThresholdTitle, thresholdHeartRate)
    }

    var note: String? {
        guard thresholdHeartRate != nil else { return WorkoutDetailConstants.rulerMissingThreshold }
        guard let divergence else { return nil }
        let format = divergence < 0 ? WorkoutDetailConstants.rulerDivergenceBelow : WorkoutDetailConstants.rulerDivergenceAbove
        return String(format: format, abs(divergence))
    }
}

extension ZoneBar {
    var hasTime: Bool {
        seconds.contains { $0.isFinite && $0 > 0 }
    }

    var timeText: String? {
        guard !seconds.isEmpty else { return nil }
        return seconds.enumerated()
            .map { index, value in "Z\(index + 1) \(WorkoutFormat.clock(value.isFinite ? max(0, value) : 0))" }
            .joined(separator: WorkoutDetailConstants.rulerTimeSeparator)
    }

    func segments(in range: ClosedRange<Int>) -> [ZoneSegment] {
        floors.indices.map { index in
            let start = index == 0 ? range.lowerBound : floors[index]
            let end = index + 1 < floors.count ? floors[index + 1] : range.upperBound
            return ZoneSegment(zone: index + 1, start: Self.position(start, in: range), end: Self.position(end, in: range))
        }
    }

    func marks(in range: ClosedRange<Int>) -> [ZoneMark] {
        floors.enumerated()
            .filter { $0.element > 0 && range.contains($0.element) }
            .map { ZoneMark(id: $0.offset, bpm: $0.element, position: Self.position($0.element, in: range)) }
    }

    private static func position(_ bpm: Int, in range: ClosedRange<Int>) -> Double {
        let span = Double(range.upperBound - range.lowerBound)
        guard span > 0 else { return 0 }
        return min(max(Double(bpm - range.lowerBound) / span, 0), 1)
    }
}
