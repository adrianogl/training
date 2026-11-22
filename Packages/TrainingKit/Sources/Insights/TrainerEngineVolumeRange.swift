import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static func volumeRange(structure: [Int: TrainerDayKind], paces: TrainerPaces, target: TrainerTarget) -> TrainerVolumeRange {
        let limit = largestWeek(structure: structure, paces: paces, target: target, easySeconds: C.easyMaximumSeconds)
        let comfortable = largestWeek(structure: structure, paces: paces, target: target, easySeconds: C.easyComfortSeconds)
        var minimum = C.metersPerKilometer
        while minimum < limit && minimumWeek(structure: structure, meters: minimum, paces: paces, target: target) > minimum {
            minimum += C.metersPerKilometer
        }
        return TrainerVolumeRange(minimum: minimum, comfortable: max(min(comfortable, limit), minimum), limit: max(limit, minimum))
    }

    public static func suggestedRuns(ranges: [Int: TrainerVolumeRange], current: Int, peakMeters: Double) -> Int? {
        guard let range = ranges[current], !range.fitsComfortably(peakMeters) else { return nil }
        let candidates = peakMeters > range.comfortable ? ranges.keys.filter { $0 > current }.sorted() : ranges.keys.filter { $0 < current }.sorted(by: >)
        return candidates.first { ranges[$0]?.fitsComfortably(peakMeters) == true }
    }

    public static func extraDay(
        preference: TrainerDayPreference, structure: [Int: TrainerDayKind], weekMeters: Double, paces: TrainerPaces, target: TrainerTarget
    ) -> TrainerExtraDay? {
        let current = peakWeekMeters(structure: structure, peakMeters: weekMeters, paces: paces, target: target)
        let currentEasy = averageEasy(current, structure: structure)
        let free = C.daysPerWeek - preference.offDays.subtracting([preference.longDay]).count
        guard currentEasy / C.metersPerKilometer * paces.easy > C.easyComfortSeconds,
              preference.runs < min(TrainerDayPreference.runsRange.upperBound, free) else { return nil }
        var next = preference
        next.runs += 1
        let nextStructure = suggestedStructure(next)
        let nextMeters = peakWeekMeters(structure: nextStructure, peakMeters: weekMeters, paces: paces, target: target)
        let nextEasy = averageEasy(nextMeters, structure: nextStructure)
        let currentWeek = current.values.reduce(0, +)
        let nextWeek = nextMeters.values.reduce(0, +)
        guard nextEasy < currentEasy || nextWeek > currentWeek else { return nil }
        return TrainerExtraDay(
            preference: next, structure: nextStructure, weekMeters: weekMeters,
            currentEasyMeters: currentEasy, currentEasySeconds: currentEasy / C.metersPerKilometer * paces.easy, nextEasyMeters: nextEasy,
            currentLongMeters: longRun(current, structure: structure), nextLongMeters: longRun(nextMeters, structure: nextStructure),
            currentWeekMeters: currentWeek, nextWeekMeters: nextWeek
        )
    }

    private static func averageEasy(_ meters: [Int: Double], structure: [Int: TrainerDayKind]) -> Double {
        let easy = meters.filter { structure[$0.key] == .easy }.values
        return easy.isEmpty ? 0 : easy.reduce(0, +) / Double(easy.count)
    }

    private static func longRun(_ meters: [Int: Double], structure: [Int: TrainerDayKind]) -> Double {
        meters.first { structure[$0.key] == .long }?.value ?? 0
    }

    private static func largestWeek(structure: [Int: TrainerDayKind], paces: TrainerPaces, target: TrainerTarget, easySeconds: Double) -> Double {
        var meters = roundKilometers(min(
            C.volumeRangeCeilingMeters,
            capacity(structure: structure, meters: C.volumeRangeCeilingMeters, paces: paces, target: target, easySeconds: easySeconds)
        ))
        while meters > C.metersPerKilometer && capacity(structure: structure, meters: meters, paces: paces, target: target, easySeconds: easySeconds) < meters {
            meters -= C.metersPerKilometer
        }
        return meters
    }
}
