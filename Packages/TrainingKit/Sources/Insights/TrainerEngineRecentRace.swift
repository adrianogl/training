import Foundation

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static func pacesFromRecentRace(meters: Double, seconds: Double) -> [TrainerPaceKind: Double] {
        guard meters > 0, seconds > 0 else { return [:] }
        func pace(at distance: Double) -> Double {
            seconds * pow(distance / meters, C.riegelExponent) / (distance / C.metersPerKilometer)
        }
        let fiveK = pace(at: C.recentRaceFiveK)
        let floor = pace(at: C.marathonMeters) * C.easyOverMarathon
        let easy = max(fiveK * C.recentRaceEasyFactor, floor)
        return [
            .easy: easy.rounded(),
            .long: max(easy - C.longBelowEasy, floor).rounded(),
            .threshold: pace(at: C.recentRaceThresholdMeters).rounded(),
            .vo2max: (fiveK - C.recentRaceVo2BelowFiveK).rounded(),
        ]
    }

    public static func previewing(_ paces: TrainerPaces, overrides: [TrainerPaceKind: Double]) -> TrainerPaces {
        applying(overrides, to: paces)
    }
}
