import FITReader

public func flatPace(_ lap: LapSummary) -> Double? {
    let speed = lap.avgSpeed ?? (lap.timerSeconds > 0 ? lap.distance / lap.timerSeconds : 0)
    guard speed > 0 else { return nil }
    let pace = 1_000 / speed
    guard hasElevation(lap) else { return pace }
    return flatPace(pace, distance: lap.distance, climb: lap.climb ?? 0, descent: lap.descent ?? 0)
}

public func flatPace(_ pace: Double, distance: Double, climb: Double, descent: Double) -> Double {
    guard distance > 0, climb >= AnalysisConstants.elevationMinimum || descent >= AnalysisConstants.elevationMinimum else { return pace }
    return pace / (1 + AnalysisConstants.climbCost * climb / distance - AnalysisConstants.descentGain * descent / distance)
}

public func hasElevation(_ lap: LapSummary) -> Bool {
    (lap.climb ?? 0) >= AnalysisConstants.elevationMinimum || (lap.descent ?? 0) >= AnalysisConstants.elevationMinimum
}
