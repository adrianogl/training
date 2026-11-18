import Foundation

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static func pacesFromRecentRace(meters: Double, seconds: Double) -> [TrainerPaceKind: Double] {
        guard meters > 0, seconds > 0 else { return [:] }
        func pace(at distance: Double) -> Double {
            seconds * pow(distance / meters, C.riegelExponent) / (distance / C.metersPerKilometer)
        }
        let fiveK = pace(at: C.recentRaceFiveK)
        let easy = fiveK * C.recentRaceEasyFactor
        return [
            .easy: easy.rounded(),
            .long: (easy - C.longBelowEasy).rounded(),
            .threshold: pace(at: C.recentRaceThresholdMeters).rounded(),
            .vo2max: (fiveK - C.recentRaceVo2BelowFiveK).rounded(),
        ]
    }

    public static func previewing(_ paces: TrainerPaces, overrides: [TrainerPaceKind: Double]) -> TrainerPaces {
        applying(overrides, to: paces)
    }
}
