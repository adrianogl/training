import Foundation
import Metrics
import TrainingCore
import WorkoutAnalysis

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    public static func paces(history: TrainerHistory, today: Day) -> TrainerPaces {
        let since = today.adding(days: -C.paceWindowDays)
        let runs = history.runs.filter { $0.day >= since && $0.day <= today && $0.meters > 0 && $0.seconds > 0 }
        func paces(of kind: RunKind) -> [Double] {
            runs.filter { $0.kind == kind }.map { $0.seconds / $0.meters * C.metersPerKilometer }
        }
        let easyPaces = paces(of: .easy)
        let tempoPaces = paces(of: .tempo)
        let allPaces = runs.map { $0.seconds / $0.meters * C.metersPerKilometer }
        let easyMedian = median(easyPaces) ?? median(allPaces) ?? C.fallbackEasyPace
        let thresholdWork = runs.filter { $0.kind == .tempo && ($0.workPaceSeconds ?? 0) > 0 }
            .sorted { $0.day > $1.day }
            .prefix(C.workPaceRuns)
            .compactMap { run in run.workPaceSeconds.map { $0 + (run.workFractioned ? C.thresholdFractionedOffset : 0) } }
        let threshold: Double
        let thresholdSource: TrainerPaceSource
        if let middle = median(thresholdWork) {
            (threshold, thresholdSource) = (middle, .work)
        } else if let predicted = history.predictions[C.thresholdPredictionMeters] {
            (threshold, thresholdSource) = (predicted / (C.thresholdPredictionMeters / C.metersPerKilometer) + C.thresholdAbovePrediction, .prediction)
        } else if let middle = median(tempoPaces) {
            (threshold, thresholdSource) = (middle, .history)
        } else {
            (threshold, thresholdSource) = (easyMedian - C.thresholdBelowEasy, .fallback)
        }
        let marathon = equivalentPace(threshold: threshold, meters: C.marathonMeters)
        let easyFloor = marathon * C.easyOverMarathon
        let longMedian = median(paces(of: .long)) ?? easyMedian - C.longBelowEasy
        return TrainerPaces(
            easy: max(easyMedian, easyFloor), long: max(longMedian, easyFloor), threshold: threshold,
            vo2max: vo2Pace(threshold: threshold), race: nil, marathon: marathon,
            easyRuns: easyPaces.count, thresholdRuns: tempoPaces.count, vo2Runs: paces(of: .intervals).count,
            thresholdSource: thresholdSource, vo2Source: nil, thresholdWorkRuns: thresholdWork.count, vo2WorkRuns: nil
        )
    }

    public static func equivalentPace(threshold: Double, meters: Double) -> Double {
        let seconds = threshold * C.recentRaceThresholdMeters / C.metersPerKilometer
        return riegel(seconds: seconds, from: C.recentRaceThresholdMeters, to: meters, exponent: C.riegelExponent) / (meters / C.metersPerKilometer)
    }

    static func vo2Pace(threshold: Double) -> Double {
        equivalentPace(threshold: threshold, meters: C.recentRaceFiveK) - C.recentRaceVo2BelowFiveK
    }

    public static func fractionedThresholdPace(_ paces: TrainerPaces) -> Double {
        paces.threshold - C.thresholdFractionedOffset
    }

    public static func racePaceZone(meters: Double?) -> Int {
        (meters ?? 0) >= C.marathonZoneRaceMeters ? TrainerZonesConstants.marathon : TrainerZonesConstants.threshold
    }

    static func targetPace(paces: TrainerPaces, target: TrainerTarget, week: TrainerWeek?, weeks: [TrainerWeek]) -> Double {
        let goal = paces.race
        guard let meters = target.distanceMeters, meters > 0 else { return max(goal ?? paces.threshold, paces.threshold) }
        if meters >= C.marathonZoneRaceMeters { return max(goal ?? paces.marathonPace, paces.threshold) }
        let start = equivalentPace(threshold: paces.threshold, meters: meters)
        let end = max(goal ?? paces.threshold, paces.threshold)
        let specific = weeks.filter { $0.phase == .specific }.map(\.index).sorted()
        let progress: Double
        if let week, let first = specific.first, let last = specific.last {
            if week.index <= first {
                progress = specific.count == 1 && week.index == first ? 1 : 0
            } else if week.index >= last {
                progress = 1
            } else {
                progress = Double(week.index - first) / Double(last - first)
            }
        } else {
            progress = week?.phase == .taper ? 1 : 0
        }
        return max(start + (end - start) * progress, paces.threshold)
    }

    public static func resolvedPaces(
        history: TrainerHistory, today: Day, target: TrainerTarget, overrides: [TrainerPaceKind: Double]
    ) -> TrainerPaces {
        var result = paces(history: history, today: today)
        result.race = racePace(target)
        return applying(overrides, to: result)
    }

    static func applying(_ overrides: [TrainerPaceKind: Double], to paces: TrainerPaces) -> TrainerPaces {
        var result = paces
        if let value = overrides[.easy] { result.easy = value }
        if let value = overrides[.long] { result.long = value }
        if let value = overrides[.threshold] {
            result.threshold = value
            result.thresholdSource = .manual
            result.marathon = equivalentPace(threshold: value, meters: C.marathonMeters)
            result.vo2max = vo2Pace(threshold: value)
            result.vo2Source = nil
            let floor = result.marathonPace * C.easyOverMarathon
            if overrides[.easy] == nil { result.easy = max(result.easy, floor) }
            if overrides[.long] == nil { result.long = max(result.long, floor) }
        }
        if let value = overrides[.vo2max] {
            result.vo2max = value
            result.vo2Source = .manual
        }
        if let value = overrides[.race] { result.race = value }
        return result
    }

    public static func racePace(_ target: TrainerTarget) -> Double? {
        if target.kind == .paceDistance { return target.goalPace }
        guard let goal = target.goalSeconds, let meters = target.distanceMeters, meters > 0 else { return nil }
        return goal / (meters / C.metersPerKilometer)
    }

    public static func requiredThreshold(target: TrainerTarget) -> Double? {
        guard target.kind == .paceDistance, let pace = target.goalPace, let meters = target.distanceMeters, meters > 0 else { return nil }
        let equivalent = riegel(seconds: pace * meters / C.metersPerKilometer, from: meters, to: C.thresholdEquivalenceMeters)
        return equivalent / (C.thresholdEquivalenceMeters / C.metersPerKilometer) + C.thresholdFromTenKmOffset
    }

    public static func goalPaceSummary(target: TrainerTarget, paces: TrainerPaces) -> String? {
        guard let needed = requiredThreshold(target: target), let pace = target.goalPace, let meters = target.distanceMeters else { return nil }
        return T.thresholdNeed(current: paces.threshold, goal: pace, meters: meters, needed: needed)
    }

    static func band(_ pace: Double, _ width: Double) -> (low: Double, high: Double) {
        ((pace - width).rounded(), (pace + width).rounded())
    }
}

public extension TrainerPaces {
    var marathonPace: Double {
        marathon ?? TrainerEngine.equivalentPace(threshold: threshold, meters: TrainerEngineConstants.marathonMeters)
    }
}
