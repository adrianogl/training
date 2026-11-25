import Foundation
import GarminAPI
import Insights
import TrainingCore

enum PlannedHourHeat {
    private typealias C = PlannedHourHeatConstants

    static func referencePace(_ input: BriefingInput) -> Double? {
        if let target = PlannedBriefingBuilder.paceTarget(input.plan) { return (target.fast + target.slow) / 2 }
        let paces = input.similar.map(\.paceSecondsPerKm).filter { $0 > 0 }
        if !paces.isEmpty { return paces.reduce(0, +) / Double(paces.count) }
        return input.easyBand.map { ($0.fastest + $0.slowest) / 2 }
    }

    static func seconds(_ hours: [HourlyWeather], pace: Double?, hotSessions: Int) -> [Int: Int] {
        guard let pace else { return [:] }
        let pairs = hours.compactMap { hour -> (Int, Int)? in
            guard let dewPoint = hour.dewPoint else { return nil }
            let share = WeatherAdjustment.heatShare(
                temperature: hour.temperature, dewPoint: dewPoint, radiation: hour.radiation, hotSessions: hotSessions
            )
            return (hour.hour, DayAdjust.heatOffset(pace, share: share))
        }
        return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }

    static func comparison(best: Int, hours: [HourlyWeather], heat: [Int: Int], startHour: Int?) -> HourHeatComparison? {
        guard let bestSeconds = heat[best] else { return nil }
        let reference = startHour.flatMap { heat[$0] != nil ? $0 : nil }
            ?? hours.map(\.hour).filter { heat[$0] != nil }.max { (heat[$0] ?? 0, -$0) < (heat[$1] ?? 0, -$1) }
        guard let reference, reference != best, let referenceSeconds = heat[reference],
              referenceSeconds - bestSeconds >= C.minimumSavedSeconds else { return nil }
        return HourHeatComparison(best: best, reference: reference, saved: referenceSeconds - bestSeconds)
    }

    static func paces(_ comparison: HourHeatComparison?, plan: PlannedWorkout, heat: [Int: Int]) -> [BestHourPace] {
        guard let comparison, let target = PlannedBriefingBuilder.paceTarget(plan) else { return [] }
        let base = Int(((target.fast + target.slow) / 2).rounded())
        return [comparison.best, comparison.reference].compactMap { hour in
            heat[hour].map { BestHourPace(hour: hour, seconds: base + $0, extra: $0) }
        }
    }

    static func tone(_ seconds: Int) -> HourHeatTone {
        if seconds >= C.hotSeconds { return .hot }
        if seconds >= C.warmSeconds { return .warm }
        return .mild
    }
}
