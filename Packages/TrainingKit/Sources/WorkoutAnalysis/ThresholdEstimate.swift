import FITReader
import Foundation
import Storage

private typealias C = ThresholdEstimateConstants

public func estimateThresholdHeartRate(
    _ record: ActivityRecord, samples: [FITSample], heatFactor: Double?, raceGoalKms: [Double]
) -> Int? {
    guard classifyRun(record, longGoalKm: nil, raceGoalKms: raceGoalKms) == .tempo,
          let data = record.structureData,
          let structure = try? JSONDecoder().decode(WorkoutStructure.self, from: data),
          hasPrescription(structure)
    else { return nil }
    let blocks = buildBlocks(structure, zones: nil)
    guard workPace(blocks: blocks) != nil else { return nil }
    return estimateThresholdHeartRate(blocks: blocks, samples: samples, heatFactor: heatFactor)
}

public func discardsThresholdEstimate(heatFactor: Double?) -> Bool {
    (heatFactor ?? 0) >= C.maximumHeatFactor
}

public func estimateThresholdHeartRate(blocks: [WorkoutBlock], samples: [FITSample], heatFactor: Double?) -> Int? {
    guard !discardsThresholdEstimate(heatFactor: heatFactor) else { return nil }
    let starts = blocks.flatMap(\.laps).map(\.startOffset).sorted()
    let spans = blocks.filter { $0.kind == .active }.compactMap { block -> ClosedRange<Double>? in
        guard let first = block.laps.first, let last = block.laps.last else { return nil }
        let end = starts.first { $0 > last.startOffset } ?? last.startOffset + last.timerSeconds
        return end > first.startOffset ? first.startOffset...end : nil
    }
    guard !spans.isEmpty else { return nil }
    let shortRests = zip(spans, spans.dropFirst()).allSatisfy {
        $1.lowerBound - $0.upperBound <= C.fractionedMaximumRestSeconds + C.restToleranceSeconds
    }
    if spans.count > 1, shortRests {
        let heartRates = spans.suffix(C.fractionedLastBlocks).flatMap { span in
            heartRates(in: samples, from: span.lowerBound + C.blockWarmupSeconds, to: span.upperBound)
        }
        return mean(heartRates)
    }
    guard let longest = spans.max(by: { duration($0) < duration($1) }),
          duration(longest) >= C.continuousMinimumSeconds,
          !hasPause(in: samples, span: longest)
    else { return nil }
    return mean(heartRates(in: samples, from: (longest.lowerBound + longest.upperBound) / 2, to: longest.upperBound))
}

public func sustainedMaxHeartRate(_ samples: [FITSample]) -> Int? {
    let points = samples.compactMap { sample in sample.heartRate.map { (t: sample.t, heartRate: $0) } }.sorted { $0.t < $1.t }
    var best: Int?
    for start in points.indices {
        var lowest = points[start].heartRate
        var end = start + 1
        while end < points.count, points[end].t - points[end - 1].t <= C.maximumSampleGapSeconds {
            lowest = min(lowest, points[end].heartRate)
            if points[end].t - points[start].t >= C.sustainedSeconds {
                best = max(best ?? lowest, lowest)
                break
            }
            end += 1
        }
    }
    return best
}

private func duration(_ span: ClosedRange<Double>) -> Double {
    span.upperBound - span.lowerBound
}

private func heartRates(in samples: [FITSample], from start: Double, to end: Double) -> [Int] {
    samples.filter { $0.t >= start && $0.t < end }.compactMap(\.heartRate)
}

private func mean(_ values: [Int]) -> Int? {
    guard values.count >= C.minimumHeartRateSamples else { return nil }
    return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
}

private func hasPause(in samples: [FITSample], span: ClosedRange<Double>) -> Bool {
    let points = samples.filter { span.contains($0.t) }.compactMap { sample in sample.distance.map { (t: sample.t, distance: $0) } }
    var slowSeconds = 0.0
    for (previous, point) in zip(points, points.dropFirst()) {
        let interval = point.t - previous.t
        guard interval > 0 else { continue }
        if point.distance - previous.distance < interval * AnalysisConstants.pauseMaximumSpeed {
            slowSeconds += interval
            if slowSeconds > C.continuousMaximumPauseSeconds { return true }
        } else {
            slowSeconds = 0
        }
    }
    return false
}
