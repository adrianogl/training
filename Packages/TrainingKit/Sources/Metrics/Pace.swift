import FITReader

public func zone2Pace(_ s: [FITSample], zone2: ClosedRange<Int>) -> Double? {
    let speeds = s.compactMap { sample -> Double? in
        guard sample.t >= RunMetricsConstants.warmupSeconds,
              let heartRate = sample.heartRate, zone2.contains(heartRate),
              let speed = sample.speed, speed > 0
        else { return nil }
        return speed
    }
    guard Double(speeds.count) * RunMetricsConstants.sampleInterval >= RunMetricsConstants.minimumSteadySeconds,
          let average = mean(speeds)
    else { return nil }
    return 1000 / average
}

public func thresholdPace(_ runs: [[FITSample]], lthr: Int) -> Double? {
    var paces: [Double] = []
    for run in runs {
        var segment: [Double] = []
        func close() {
            if Double(segment.count) * RunMetricsConstants.sampleInterval >= RunMetricsConstants.minimumSteadySeconds {
                paces.append(contentsOf: segment.map { 1000 / $0 })
            }
            segment = []
        }
        for sample in run {
            if let heartRate = sample.heartRate,
               abs(heartRate - lthr) <= RunMetricsConstants.thresholdHeartRateTolerance,
               let speed = sample.speed, speed > 0 {
                segment.append(speed)
            } else {
                close()
            }
        }
        close()
    }
    return median(paces)
}
