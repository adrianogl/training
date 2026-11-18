import FITReader
import TrainingCore
import WorkoutAnalysis

enum KilometerElevationBuilder {
    static func elevation(_ block: WorkoutBlock) -> KilometerElevation? {
        guard block.laps.count == 1, let lap = block.laps.first, hasElevation(lap), let pace = flatPace(lap) else { return nil }
        return KilometerElevation(
            climb: Int((lap.climb ?? 0).rounded()),
            descent: Int((lap.descent ?? 0).rounded()),
            flatPace: WorkoutListModel.clockText(pace)
        )
    }
}

enum KilometerWindBuilder {
    static func wind(_ block: WorkoutBlock) -> KilometerWind? {
        guard let factor = block.windFactor, let headwind = block.headwind, let speed = block.avgSpeed, speed > 0,
              abs(windSeconds(block) ?? 0) >= RunWeatherConstants.windEffectSeconds else { return nil }
        let pace = WorkoutConstants.metersPerKilometer / speed
        return KilometerWind(
            headwind: headwind > 0,
            speedText: String(format: WorkoutDetailConstants.windSpeedFormat, Int((abs(headwind) * RunWeatherConstants.metersPerSecondToKmh).rounded())),
            calmPace: WorkoutListModel.clockText(pace / (1 + factor))
        )
    }
}
