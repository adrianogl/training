public struct LoadFocus: Sendable, Equatable {
    public var lowAerobic: Double
    public var highAerobic: Double
    public var anaerobic: Double

    public init(lowAerobic: Double, highAerobic: Double, anaerobic: Double) {
        self.lowAerobic = lowAerobic
        self.highAerobic = highAerobic
        self.anaerobic = anaerobic
    }

    public static let target = LoadFocusTarget(low: 0.60...0.75, high: 0.20...0.35, anaerobic: 0.05...0.10)
}

public struct LoadFocusTarget: Sendable, Equatable {
    public let low: ClosedRange<Double>
    public let high: ClosedRange<Double>
    public let anaerobic: ClosedRange<Double>
}

public func loadFocus(_ items: [(load: Double, zoneSeconds: [Double])]) -> LoadFocus? {
    var low = 0.0
    var high = 0.0
    var anaerobic = 0.0
    for item in items {
        guard item.zoneSeconds.count == 5, item.load > 0 else { continue }
        let total = item.zoneSeconds.reduce(0, +)
        guard total > 0 else { continue }
        let z = item.zoneSeconds
        low += item.load * (z[0] + z[1]) / total
        high += item.load * (z[2] + z[3]) / total
        anaerobic += item.load * z[4] / total
    }
    let sum = low + high + anaerobic
    guard sum > 0 else { return nil }
    return LoadFocus(lowAerobic: low / sum, highAerobic: high / sum, anaerobic: anaerobic / sum)
}
