import FITReader

public func runContinuity(_ samples: [FITSample]) -> RunContinuity? {
    let points = samples.compactMap { sample in sample.distance.map { (t: sample.t, distance: $0) } }.sorted { $0.t < $1.t }
    guard let first = points.first, let last = points.last, last.distance > first.distance else { return nil }
    var pauses: [RunPause] = []
    var movingSeconds = 0.0
    var segmentStart = first.distance
    var longest = 0.0
    var slowStart: (t: Double, distance: Double)?
    var slowSeconds = 0.0
    var previous = first

    func closeSlow() {
        guard let start = slowStart else { return }
        if slowSeconds >= AnalysisConstants.pauseGapSeconds {
            pauses.append(RunPause(startMeters: start.distance - first.distance, seconds: slowSeconds))
            longest = max(longest, start.distance - segmentStart)
            segmentStart = previous.distance
        } else {
            movingSeconds += slowSeconds
        }
        slowStart = nil
        slowSeconds = 0
    }

    for point in points.dropFirst() {
        let interval = point.t - previous.t
        guard interval > 0 else { continue }
        let slow = point.distance - previous.distance < interval * AnalysisConstants.pauseMaximumSpeed
        if slow {
            if slowStart == nil { slowStart = previous }
            slowSeconds += interval
        } else {
            closeSlow()
            movingSeconds += interval
        }
        previous = point
    }
    closeSlow()
    longest = max(longest, last.distance - segmentStart)
    return RunContinuity(totalMeters: last.distance - first.distance, movingSeconds: movingSeconds, pauses: pauses, longestContinuousMeters: longest)
}
