import FITReader
import Foundation
import Metrics
import WorkoutAnalysis

private typealias C = DetailedAnalysisConstants

func detailedSplits(_ samples: [FITSample]) -> [DetailedSplit] {
    var rows: [DetailedSplit] = []
    var integrated = 0.0
    var previousSample: FITSample?
    var startDistance: Double?
    var previousTime = 0.0
    var previousDistance = 0.0
    var seconds = 0.0
    var heartRates: [Double] = []
    for sample in samples.sorted(by: { $0.t < $1.t }) {
        if let previousSample, let speed = previousSample.speed {
            integrated += speed * max(0, sample.t - previousSample.t)
        }
        previousSample = sample
        let distance = sample.distance ?? integrated
        guard let start = startDistance else {
            startDistance = distance
            previousTime = sample.t
            previousDistance = distance
            sample.heartRate.map { heartRates.append(Double($0)) }
            continue
        }
        let interval = sample.t - previousTime
        let paused = interval > AnalysisConstants.pauseGapSeconds && distance - previousDistance < interval * AnalysisConstants.pauseMaximumSpeed
        if !paused { seconds += max(0, interval) }
        previousTime = sample.t
        previousDistance = distance
        sample.heartRate.map { heartRates.append(Double($0)) }
        let covered = distance - start
        guard covered >= C.metersPerKilometer else { continue }
        if seconds > 0 {
            rows.append(DetailedSplit(km: rows.count + 1, paceSeconds: (seconds * C.metersPerKilometer / covered * 10).rounded() / 10, heartRate: average(heartRates)))
        }
        startDistance = distance
        seconds = 0
        heartRates = []
    }
    return rows
}

func fadeKilometer(_ paces: [Double]) -> Int? {
    guard paces.count > C.fadeMinimumKm else { return nil }
    for km in C.fadeMinimumKm..<paces.count {
        guard let baseline = median(Array(paces[0..<(km - 1)])) else { continue }
        if paces[km - 1] - baseline >= C.fadeSeconds && paces[km] - baseline >= C.fadeSeconds { return km }
    }
    return nil
}

func decoupling(_ splits: [DetailedSplit]) -> Double? {
    let rows = splits.compactMap { split in split.heartRate.map { (speed: C.metersPerKilometer / split.paceSeconds, heartRate: $0) } }
    guard rows.count >= C.driftMinimumKm else { return nil }
    let half = rows.count / 2
    func efficiency(_ part: ArraySlice<(speed: Double, heartRate: Double)>) -> Double? {
        guard let speed = average(part.map(\.speed)), let heartRate = average(part.map(\.heartRate)), heartRate > 0 else { return nil }
        return speed / heartRate
    }
    guard let first = efficiency(rows.prefix(half)), let second = efficiency(rows.suffix(half)), first > 0 else { return nil }
    return (first - second) / first * 100
}

func openingPace(_ splits: [DetailedSplit]) -> Double? {
    guard splits.count >= C.startKm else { return nil }
    return average(splits.prefix(C.startKm).map(\.paceSeconds))
}

func linearFit(_ points: [(x: Double, y: Double)]) -> (slope: Double, intercept: Double)? {
    guard points.count >= 2, let meanX = average(points.map(\.x)), let meanY = average(points.map(\.y)) else { return nil }
    let variance = points.reduce(0) { $0 + ($1.x - meanX) * ($1.x - meanX) }
    guard variance > 0 else { return nil }
    let covariance = points.reduce(0) { $0 + ($1.x - meanX) * ($1.y - meanY) }
    let slope = covariance / variance
    return (slope, meanY - slope * meanX)
}

func standardDeviation(_ values: [Double]) -> Double? {
    guard let mean = average(values) else { return nil }
    return (values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)).squareRoot()
}
