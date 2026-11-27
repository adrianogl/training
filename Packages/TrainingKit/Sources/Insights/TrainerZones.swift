import GarminAPI
import Foundation
import Metrics
import TrainingCore

private typealias C = TrainerZonesConstants

public enum TrainerZones {
    public static func zone(_ step: TrainerStep, in workout: TrainerWorkout) -> Int? {
        if step.kind != .recovery, let zone = step.zone { return zone }
        switch step.kind {
        case .recovery: return nil
        case .warmup, .cooldown: return C.easy
        case .steady: return step.method.map { zone(for: $0) } ?? C.easy
        case .work:
            if let method = step.method { return zone(for: method) }
            switch workout.kind {
            case .threshold: return C.threshold
            case .race: return C.marathon
            case .long: return C.easy
            default: return C.fast
            }
        }
    }

    public static func zone(for method: TrainerMethod, raceMeters: Double? = nil) -> Int {
        switch method {
        case .cruiseIntervals, .tempo: C.threshold
        case .intervals, .repetition, .strides: C.fast
        case .racePace, .goalPace: raceMeters.map { TrainerEngine.racePaceZone(meters: $0) } ?? C.marathon
        }
    }

    public static func zone(forPace pace: Double, paces: TrainerPaces) -> Int {
        let centers = [(C.fast, paces.vo2max), (C.threshold, paces.threshold), (C.marathon, paces.marathonPace), (C.easy, paces.easy)]
        return centers.min { abs($0.1 - pace) < abs($1.1 - pace) }?.0 ?? C.easy
    }

    public static func bands(thresholdHeartRate: Int?, paces: TrainerPaces?, maxHeartRate: Int? = nil) -> [TrainerZoneBand] {
        let floors = thresholdHeartRate.map { thresholdZones(thresholdHeartRate: $0).floors } ?? []
        return (1...C.zoneCount).map { zone in
            let pace = paces.flatMap { paceBand(zone: zone, paces: $0) }
            let low = floors.indices.contains(zone - 1) && zone > 1 ? floors[zone - 1] : nil
            let high = floors.indices.contains(zone) ? floors[zone] - 1 : zone == C.zoneCount ? maxHeartRate : nil
            return TrainerZoneBand(zone: zone, heartRateLow: low, heartRateHigh: high, paceLow: pace?.low, paceHigh: pace?.high)
        }
    }

    public static func paceBand(zone: Int, paces: TrainerPaces) -> (low: Double, high: Double)? {
        switch zone {
        case C.easy: TrainerEngine.band(paces.easy, TrainerEngineConstants.easyBand)
        case C.marathon: TrainerEngine.band(paces.marathonPace, TrainerEngineConstants.qualityBand)
        case C.threshold:
            (TrainerEngine.band(TrainerEngine.fractionedThresholdPace(paces), TrainerEngineConstants.qualityBand).low,
             TrainerEngine.band(paces.threshold, TrainerEngineConstants.qualityBand).high)
        case C.fast: TrainerEngine.band(paces.vo2max, TrainerEngineConstants.qualityBand)
        default: nil
        }
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
            switch step.secondaryTarget {
            case .zone(let zone): return min(max(zone, 1), TrainerZonesConstants.zoneCount)
            case .heartRate(let low, let high):
                let middle = Int(((low + high) / 2).rounded())
                if bands.contains(where: { $0.heartRateLow != nil }), let zone = bands.last(where: { ($0.heartRateLow ?? 0) <= middle })?.zone { return zone }
            case .pace, nil: break
            }
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
