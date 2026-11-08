import TrainingCore

public func smoothedVo2max(_ runs: [(Day, Double)]) -> [(Day, Double)] {
    var smoothed: Double?
    return runs.sorted { $0.0 < $1.0 }.map { day, value in
        let next = smoothed.map { $0 + (value - $0) / RunMetricsConstants.vo2SmoothingDays } ?? value
        smoothed = next
        return (day, next)
    }
}
