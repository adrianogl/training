import FITReader
import TrainingCore

public func thresholdZones(thresholdHeartRate: Int) -> HeartRateZones {
    let inner = ThresholdZonesConstants.floorFractions.map { Int((Double(thresholdHeartRate) * $0).rounded()) }
    return HeartRateZones(floors: [0] + inner + [thresholdHeartRate], maxHeartRate: nil)
}

public func zoneSeconds(_ samples: [FITSample], zones: HeartRateZones) -> [Double]? {
    guard !zones.floors.isEmpty else { return nil }
    var seconds = [Double](repeating: 0, count: zones.floors.count)
    for (index, sample) in samples.enumerated() {
        guard let heartRate = sample.heartRate, heartRate > 0, index + 1 < samples.count else { continue }
        let gap = min(max(samples[index + 1].t - sample.t, 0), ThresholdZonesConstants.maxSampleGap)
        let zone = zones.floors.lastIndex { heartRate >= $0 } ?? 0
        seconds[zone] += gap
    }
    return samples.contains { ($0.heartRate ?? 0) > 0 } ? seconds : nil
}

public func zoneDivergence(watchZone5Floor: Int?, thresholdHeartRate: Int?) -> Int? {
    guard let watchZone5Floor, let thresholdHeartRate else { return nil }
    let difference = watchZone5Floor - thresholdHeartRate
    return abs(difference) < ThresholdZonesConstants.minDivergence ? nil : difference
}
