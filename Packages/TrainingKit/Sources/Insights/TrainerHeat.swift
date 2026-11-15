import Foundation

private typealias C = TrainerEngineConstants

public struct TrainerHeat: Sendable, Equatable {
    public static let threshold = C.heatThreshold

    public let temperature: Double
    public let paceOffset: Double
    public let blockReduction: Double

    public var isHot: Bool { paceOffset > 0 }

    public static func assess(temperature: Double) -> TrainerHeat {
        guard temperature > C.heatThreshold else { return TrainerHeat(temperature: temperature, paceOffset: 0, blockReduction: 0) }
        let offset = temperature >= C.heatStrong ? C.heatStrongPaceOffset : C.heatPaceOffset
        return TrainerHeat(temperature: temperature, paceOffset: offset, blockReduction: C.heatBlockReduction)
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
                blocks: blocks, rest: max(rest, C.longStageRests[0]), longPace: longPace + paceOffset
            )
            let main = TrainerEngine.band(longPace + paceOffset, C.easyBand)
            result.paceLow = main.low
            result.paceHigh = main.high
            return result
        }
        result.steps = workout.steps.map { step in
            var shifted = step
            shifted.paceLow = step.paceLow.map { $0 + paceOffset }
            shifted.paceHigh = step.paceHigh.map { $0 + paceOffset }
            return shifted
        }
        result.paceLow = workout.paceLow.map { $0 + paceOffset }
        result.paceHigh = workout.paceHigh.map { $0 + paceOffset }
        return result
    }
}
