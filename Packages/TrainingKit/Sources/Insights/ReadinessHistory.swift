public func readinessMovingAverage(_ scores: [Int?], window: Int) -> [Double?] {
    scores.indices.map { index in
        guard index >= window - 1 else { return nil }
        return readinessAverage(scores[(index - window + 1)...index])
    }
}

public func readinessAverage(_ scores: some Collection<Int?>) -> Double? {
    let values = scores.compactMap { $0 }
    guard !values.isEmpty else { return nil }
    return Double(values.reduce(0, +)) / Double(values.count)
}
