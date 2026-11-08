import FITReader

public func decoupling(_ s: [FITSample]) -> Double? {
    guard let first = s.first, let last = s.last,
          last.t - first.t >= RunMetricsConstants.decouplingMinimumSeconds
    else { return nil }
    let steady = s.filter { $0.t >= RunMetricsConstants.warmupSeconds }
    guard let start = steady.first?.t, let end = steady.last?.t else { return nil }
    let midpoint = (start + end) / 2
    func ratio(_ half: [FITSample]) -> Double? {
        guard let speed = mean(half.compactMap(\.speed)),
              let heartRate = mean(half.compactMap { $0.heartRate.map(Double.init) }),
              heartRate > 0
        else { return nil }
        return speed / heartRate
    }
    guard let r1 = ratio(steady.filter { $0.t < midpoint }),
          let r2 = ratio(steady.filter { $0.t >= midpoint }),
          r1 > 0
    else { return nil }
    return (r1 - r2) / r1 * 100
}
