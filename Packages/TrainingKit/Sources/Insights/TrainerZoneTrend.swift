import FITReader
import Foundation
import Metrics
import TrainingCore
import WorkoutAnalysis

private typealias C = TrainerZoneTrendConstants
private typealias Z = TrainerZonesConstants

public enum TrainerZoneTrends {
    public static func build(
        history: TrainerHistory, runs: [TrainerZoneTrendRun], target: TrainerTarget?, overrides: [TrainerPaceKind: Double],
        thresholdHeartRates: [Day: Int], maxHeartRate: Int?, today: Day
    ) -> TrainerZoneTrend {
        let starts = weekStarts(today: today)
        var pooled: [Int: [TrainerZoneSegment]] = [:]
        let weeks = starts.map { start -> TrainerZoneWeek in
            let reference = min(start.adding(days: C.daysPerWeek - 1), today)
            var weekHistory = history
            if let predictions = history.predictionSeries[start] { weekHistory.predictions = predictions }
            let paces = TrainerEngine.applying(overrides, to: TrainerEngine.paces(history: weekHistory, today: reference))
            let bands = TrainerZones.bands(thresholdHeartRate: thresholdHeartRates[reference], paces: paces, maxHeartRate: maxHeartRate)
            let segments = runs.filter { $0.day >= start && $0.day <= reference }.flatMap { segments(of: $0, paces: paces) }
            for segment in segments { pooled[segment.zone, default: []].append(segment) }
            return TrainerZoneWeek(
                start: start, threshold: paces.threshold, targets: targets(bands),
                actual: Dictionary(grouping: segments, by: \.zone).mapValues(actual)
            )
        }
        return TrainerZoneTrend(weeks: weeks, goalThreshold: target.flatMap(goalThreshold), averages: pooled.mapValues(actual))
    }

    public static func weekStarts(today: Day) -> [Day] {
        (0..<C.weeks).reversed().map { today.weekStart.adding(days: -$0 * C.daysPerWeek) }
    }

    public static func historyStart(today: Day) -> Day {
        (weekStarts(today: today).first ?? today).adding(days: -TrainerEngineConstants.paceWindowDays)
    }

    public static func goalThreshold(_ target: TrainerTarget) -> Double? {
        guard let pace = TrainerEngine.racePace(target), let meters = target.distanceMeters, meters > 0 else { return nil }
        let reference = TrainerEngineConstants.recentRaceThresholdMeters
        let seconds = riegel(
            seconds: pace * meters / C.metersPerKilometer, from: meters, to: reference, exponent: TrainerEngineConstants.riegelExponent
        )
        return seconds / (reference / C.metersPerKilometer)
    }

    public static func thresholdChange(_ trend: TrainerZoneTrend, at index: Int) -> Double? {
        guard trend.weeks.indices.contains(index), index >= C.changeWeeks else { return nil }
        return trend.weeks[index].threshold - trend.weeks[index - C.changeWeeks].threshold
    }

    public static func paceFit(_ pace: Double, target: TrainerZoneTarget) -> TrainerZoneFit {
        if let high = target.paceHigh, pace > high { return .slower(Int((pace - high).rounded())) }
        if let low = target.paceLow, pace < low { return .faster(Int((low - pace).rounded())) }
        return .inside
    }

    public static func heartRateFit(_ heartRate: Double, target: TrainerZoneTarget) -> TrainerZoneFit {
        let value = Int(heartRate.rounded())
        if let high = target.heartRateHigh, value > high { return .above(value - high) }
        if let low = target.heartRateLow, value < low { return .below(low - value) }
        return .inside
    }

    static func targets(_ bands: [TrainerZoneBand]) -> [TrainerZoneTarget] {
        let easyHigh = bands.first { $0.zone == Z.easy }?.paceHigh
        return bands.map { band in
            let isTrot = band.zone == C.trot
            let isTop = band.zone == Z.zoneCount
            return TrainerZoneTarget(
                zone: band.zone, paceLow: isTrot ? easyHigh : band.paceLow, paceHigh: isTrot ? nil : band.paceHigh,
                heartRateLow: band.heartRateLow, heartRateHigh: isTop ? nil : band.heartRateHigh
            )
        }
    }

    static func segments(of run: TrainerZoneTrendRun, paces: TrainerPaces) -> [TrainerZoneSegment] {
        let samples = run.samples.sorted { $0.t < $1.t }
        return run.blocks.compactMap { block in
            guard block.distance > 0, block.seconds > 0, let zone = zone(of: block, run: run, paces: paces) else { return nil }
            let pace = block.seconds / block.distance * C.metersPerKilometer
            guard pace <= C.standingPace else { return nil }
            let paced = zone != C.trot || pace <= C.trotMaximumPace
            let heart = heartRate(of: block, samples: samples)
            return TrainerZoneSegment(
                zone: zone, seconds: paced ? block.seconds : 0, meters: paced ? block.distance : 0,
                heartRateSum: heart.map { $0.average * $0.seconds } ?? 0, heartRateSeconds: heart?.seconds ?? 0
            )
        }
    }

    static func zone(of block: WorkoutBlock, run: TrainerZoneTrendRun, paces: TrainerPaces) -> Int? {
        switch block.kind {
        case .warmup:
            return nil
        case .recovery, .cooldown:
            guard block.seconds >= C.trotMinimumSeconds, block.prescribed?.intensity != .rest else { return nil }
            return C.trot
        case .active:
            if case .distance(let meters)? = block.prescribed?.duration, meters <= C.shortRepMeters { return nil }
            if block.prescribed == nil, block.distance <= C.shortRepMeters { return nil }
            if case .speed(let low, let high)? = block.prescribed?.target, low > 0, high > 0 {
                let pace = C.metersPerKilometer / ((low + high) / 2)
                return TrainerZones.zone(forPace: pace, paces: paces)
            }
            switch run.kind {
            case .tempo: return block.prescribed == nil ? nil : Z.threshold
            case .intervals: return block.prescribed == nil ? nil : Z.fast
            case .easy, .long: return Z.easy
            case .race: return nil
            }
        }
    }

    static func heartRate(of block: WorkoutBlock, samples: [FITSample]) -> (average: Double, seconds: Double)? {
        guard let first = block.laps.first, let last = block.laps.last else { return nil }
        let start = first.startOffset + C.heartRateLagSeconds
        let end = last.startOffset + last.timerSeconds
        guard !samples.isEmpty else {
            let seconds = block.seconds - C.heartRateLagSeconds
            guard let average = block.avgHeartRate, seconds > 0 else { return nil }
            return (Double(average), seconds)
        }
        var sum = 0.0
        var seconds = 0.0
        for index in samples.indices.dropLast() {
            let sample = samples[index]
            guard sample.t >= start, sample.t < end, let heartRate = sample.heartRate, heartRate > 0 else { continue }
            let gap = min(max(min(samples[index + 1].t, end) - sample.t, 0), C.maxSampleGap)
            sum += Double(heartRate) * gap
            seconds += gap
        }
        return seconds > 0 ? (sum / seconds, seconds) : nil
    }

    static func actual(_ segments: [TrainerZoneSegment]) -> TrainerZoneActual {
        let meters = segments.reduce(0.0) { $0 + $1.meters }
        let seconds = segments.reduce(0.0) { $0 + $1.seconds }
        let heartSeconds = segments.reduce(0.0) { $0 + $1.heartRateSeconds }
        return TrainerZoneActual(
            pace: meters >= C.minimumMeters ? seconds / meters * C.metersPerKilometer : nil,
            heartRate: heartSeconds > 0 ? segments.reduce(0.0) { $0 + $1.heartRateSum } / heartSeconds : nil
        )
    }
}
