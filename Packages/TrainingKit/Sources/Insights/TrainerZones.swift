import FITReader
import GarminAPI
import Foundation
import Metrics
import TrainingCore

private typealias C = TrainerZonesConstants

public enum TrainerZones {
    public static func zone(_ step: TrainerStep, in workout: TrainerWorkout) -> Int? {
        switch step.kind {
        case .recovery: return nil
        case .warmup, .cooldown: return C.easy
        case .steady: return step.method.map(zone(for:)) ?? C.easy
        case .work:
            if let method = step.method { return zone(for: method) }
            switch workout.kind {
            case .threshold: return C.threshold
            case .race: return C.racePace
            case .long: return C.easy
            default: return C.fast
            }
        }
    }

    public static func zone(for method: TrainerMethod) -> Int {
        switch method {
        case .cruiseIntervals, .tempo: C.threshold
        case .intervals, .repetition: C.fast
        case .racePace, .goalPace: C.racePace
        }
    }

    public static func zone(forPace pace: Double, paces: TrainerPaces) -> Int {
        let centers = [(C.fast, paces.vo2max), (C.threshold, paces.threshold), (C.easy, paces.easy)] + (paces.race.map { [(C.racePace, $0)] } ?? [])
        return centers.min { abs($0.1 - pace) < abs($1.1 - pace) }?.0 ?? C.easy
    }

    public static func usesHeartRateTarget(_ step: TrainerStep, in workout: TrainerWorkout) -> Bool {
        guard let zone = zone(step, in: workout), zone != C.fast else { return false }
        return step.kind != .work || step.meters >= C.heartRateTargetMinMeters
    }

    public static func bands(thresholdHeartRate: Int?, paces: TrainerPaces?) -> [TrainerZoneBand] {
        let floors = thresholdHeartRate.map { thresholdZones(thresholdHeartRate: $0).floors } ?? []
        return (1...C.zoneCount).map { zone in
            let pace = paces.flatMap { paceBand(zone: zone, paces: $0) }
            let low = floors.indices.contains(zone - 1) && zone > 1 ? floors[zone - 1] : nil
            let high = floors.indices.contains(zone) ? floors[zone] - 1 : nil
            return TrainerZoneBand(zone: zone, heartRateLow: low, heartRateHigh: high, paceLow: pace?.low, paceHigh: pace?.high)
        }
    }

    public static func paceBand(zone: Int, paces: TrainerPaces) -> (low: Double, high: Double)? {
        switch zone {
        case C.easy: TrainerEngine.band(paces.easy, TrainerEngineConstants.easyBand)
        case C.racePace: paces.race.map { TrainerEngine.band($0, TrainerEngineConstants.qualityBand) }
        case C.threshold: TrainerEngine.band(paces.threshold, TrainerEngineConstants.qualityBand)
        case C.fast: TrainerEngine.band(paces.vo2max, TrainerEngineConstants.qualityBand)
        default: nil
        }
    }

    public static func realPaces(_ runs: [[FITSample]], thresholdHeartRate: Int) -> [Int: Double] {
        let floors = thresholdZones(thresholdHeartRate: thresholdHeartRate).floors
        var seconds = [Double](repeating: 0, count: floors.count)
        var meters = [Double](repeating: 0, count: floors.count)
        for samples in runs {
            for index in samples.indices.dropLast() {
                let sample = samples[index]
                guard let heartRate = sample.heartRate, heartRate > 0, let speed = sample.speed, speed > 0 else { continue }
                let gap = min(max(samples[index + 1].t - sample.t, 0), C.maxSampleGap)
                let zone = floors.lastIndex { heartRate >= $0 } ?? 0
                seconds[zone] += gap
                meters[zone] += speed * gap
            }
        }
        var result: [Int: Double] = [:]
        for index in floors.indices where seconds[index] >= C.realMinSeconds && meters[index] > 0 {
            result[index + 1] = seconds[index] / meters[index] * 1_000
        }
        return result
    }
}

public extension TrainerZones {
    static func zone(planned step: PlannedStep, paces: TrainerPaces?, bands: [TrainerZoneBand]) -> Int? {
        switch step.target {
        case .zone(let zone): return min(max(zone, 1), TrainerZonesConstants.zoneCount)
        case .heartRate(let low, let high):
            let middle = Int(((low + high) / 2).rounded())
            return bands.last { ($0.heartRateLow ?? 0) <= middle }?.zone
        case .pace(let fastest, let slowest):
            guard let paces else { return nil }
            return zone(forPace: (fastest + slowest) / 2, paces: paces)
        case nil:
            switch step.kind {
            case .warmup, .cooldown: return TrainerZonesConstants.easy
            case .active: return paces == nil ? nil : TrainerZonesConstants.easy
            default: return nil
            }
        }
    }
}
