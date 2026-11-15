import Foundation
import Metrics
import TrainingCore

private typealias C = TrainerEngineConstants

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
        let threshold = history.predictions[C.thresholdPredictionMeters].map {
            $0 / (C.thresholdPredictionMeters / C.metersPerKilometer) + C.thresholdAbovePrediction
        } ?? median(tempoPaces) ?? easy - C.thresholdBelowEasy
        let vo2 = history.predictions[C.vo2PredictionMeters].map { $0 / (C.vo2PredictionMeters / C.metersPerKilometer) }
            ?? threshold - C.vo2BelowThreshold
        return TrainerPaces(
            easy: easy, long: long, threshold: threshold, vo2max: vo2, race: nil,
            easyRuns: easyPaces.count, thresholdRuns: tempoPaces.count, vo2Runs: paces(of: .intervals).count
        )
    }

    static func racePace(_ target: TrainerTarget) -> Double? {
        guard let goal = target.goalSeconds, let meters = target.distanceMeters, meters > 0 else { return nil }
        return goal / (meters / C.metersPerKilometer)
    }

    static func band(_ pace: Double, _ width: Double) -> (low: Double, high: Double) {
        ((pace - width).rounded(), (pace + width).rounded())
    }
}
