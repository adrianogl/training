import FITReader
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
