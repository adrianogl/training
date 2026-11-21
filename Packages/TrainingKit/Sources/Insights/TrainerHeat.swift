import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

public struct TrainerHeat: Sendable, Equatable {
    public let temperature: Double
    public let dewPoint: Double?
    public let factor: Double
    public let paceOffset: Int
    public let blockReduction: Double

    public var isHot: Bool { paceOffset > 0 }

    public static func assess(temperature: Double, dewPoint: Double?, pace: Double, hotSessions: Int = 0) -> TrainerHeat {
        guard let dewPoint else {
            return TrainerHeat(temperature: temperature, dewPoint: nil, factor: 0, paceOffset: 0, blockReduction: 0)
        }
        let raw = WeatherAdjustment.heatFactor(temperature: temperature, dewPoint: dewPoint)
        let factor = raw * (1 - WeatherAdjustment.adaptation(hotSessions: hotSessions))
        let rounded = Int((factor * pace).rounded())
        let offset = rounded < RunWeatherConstants.minimumHeatSeconds ? 0 : rounded
        return TrainerHeat(
            temperature: temperature, dewPoint: dewPoint, factor: factor, paceOffset: offset,
            blockReduction: offset > 0 && factor >= C.heatBlockFactor ? C.heatBlockReduction : 0
        )
    }

    public func apply(to workout: TrainerWorkout, longPace: Double) -> TrainerWorkout {
        guard isHot, workout.kind == .long else { return workout }
        var result = workout
        if TrainerEngine.plannedPauses(of: workout) > 0, let rest = workout.steps.first(where: { $0.restSeconds != nil })?.restSeconds {
            let sizes = TrainerEngine.blockSizes(of: workout)
            let size = max((sizes.max() ?? workout.totalMeters) - blockReduction, C.metersPerKilometer)
            let count = Int((workout.totalMeters / size).rounded(.up))
            let even = TrainerEngine.roundHalfKilometers(workout.totalMeters / Double(count))
            let blocks = (0..<count).map { $0 < count - 1 ? even : workout.totalMeters - even * Double(count - 1) }
            result.steps = TrainerEngine.longBlockSteps(
                blocks: blocks, rest: max(rest, C.longStageRests[0]), longPace: longPace + Double(paceOffset)
            )
            let main = TrainerEngine.band(longPace + Double(paceOffset), C.easyBand)
            result.paceLow = main.low
            result.paceHigh = main.high
            return result
        }
        result.steps = workout.steps.map { step in
            var shifted = step
            shifted.paceLow = step.paceLow.map { $0 + Double(paceOffset) }
            shifted.paceHigh = step.paceHigh.map { $0 + Double(paceOffset) }
            return shifted
        }
        result.paceLow = workout.paceLow.map { $0 + Double(paceOffset) }
        result.paceHigh = workout.paceHigh.map { $0 + Double(paceOffset) }
        return result
    }
}
