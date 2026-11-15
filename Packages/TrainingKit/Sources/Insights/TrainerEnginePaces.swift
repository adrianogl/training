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
        let easy = median(easyPaces) ?? median(allPaces) ?? C.fallbackEasyPace
        let long = median(paces(of: .long)) ?? easy - C.longBelowEasy
        func workPaces(of kind: RunKind) -> [Double] {
            runs.filter { $0.kind == kind && ($0.workPaceSeconds ?? 0) > 0 }
                .sorted { $0.day > $1.day }
                .prefix(C.workPaceRuns)
                .compactMap(\.workPaceSeconds)
        }
        let thresholdWork = workPaces(of: .tempo)
        let vo2Work = workPaces(of: .intervals)
        let threshold: Double
        let thresholdSource: TrainerPaceSource
        if let middle = median(thresholdWork) {
            (threshold, thresholdSource) = (middle, .work)
        } else if let predicted = history.predictions[C.thresholdPredictionMeters] {
            (threshold, thresholdSource) = (predicted / (C.thresholdPredictionMeters / C.metersPerKilometer) + C.thresholdAbovePrediction, .prediction)
        } else if let middle = median(tempoPaces) {
            (threshold, thresholdSource) = (middle, .history)
        } else {
            (threshold, thresholdSource) = (easy - C.thresholdBelowEasy, .fallback)
        }
        let vo2: Double
        let vo2Source: TrainerPaceSource
        if let middle = median(vo2Work) {
            (vo2, vo2Source) = (middle, .work)
        } else if let predicted = history.predictions[C.vo2PredictionMeters] {
            (vo2, vo2Source) = (predicted / (C.vo2PredictionMeters / C.metersPerKilometer), .prediction)
        } else {
            (vo2, vo2Source) = (threshold - C.vo2BelowThreshold, .fallback)
        }
        return TrainerPaces(
            easy: easy, long: long, threshold: threshold, vo2max: vo2, race: nil,
            easyRuns: easyPaces.count, thresholdRuns: tempoPaces.count, vo2Runs: paces(of: .intervals).count,
            thresholdSource: thresholdSource, vo2Source: vo2Source, thresholdWorkRuns: thresholdWork.count, vo2WorkRuns: vo2Work.count
        )
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
