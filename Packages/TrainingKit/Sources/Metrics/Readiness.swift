import Foundation

private func interpolate(_ x: Double, _ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double) -> Double {
    y0 + (x - x0) / (x1 - x0) * (y1 - y0)
}

public func hrvComponent(_ value: Double, _ b: HRVBaseline) -> Double {
    if value < b.lowUpper { return 0 }
    if value < b.balancedLow {
        return interpolate(value, b.lowUpper, b.balancedLow, 0, ReadinessConstants.hrvLowEdgeScore)
    }
    if value <= b.balancedUpper {
        guard b.balancedUpper > b.balancedLow else { return ReadinessConstants.hrvLowEdgeScore }
        return interpolate(value, b.balancedLow, b.balancedUpper, ReadinessConstants.hrvLowEdgeScore, ReadinessConstants.hrvBalancedTopScore)
    }
    return ReadinessConstants.hrvBalancedTopScore
}

public func loadComponent(_ ratio: Double) -> Double {
    typealias C = ReadinessConstants
    if ratio >= C.loadIdealLow && ratio <= C.loadIdealHigh { return 100 }
    if ratio > C.loadZeroLow && ratio < C.loadIdealLow {
        return interpolate(ratio, C.loadZeroLow, C.loadIdealLow, 0, 100)
    }
    if ratio > C.loadIdealHigh && ratio < C.loadZeroHigh {
        return interpolate(ratio, C.loadIdealHigh, C.loadZeroHigh, 100, 0)
    }
    return 0
}

private func clampedPercent(_ value: Double) -> Double {
    min(max(value, 0), 100)
}

public func readinessComponents(_ input: ReadinessInput) -> [ReadinessComponent: Double] {
    var scores: [ReadinessComponent: Double] = [:]
    if let value = input.hrvLastNight, let baseline = input.hrvBaseline {
        scores[.hrv] = hrvComponent(value, baseline)
    }
    if let sleep = input.sleepScore { scores[.sleep] = clampedPercent(sleep) }
    if let battery = input.bodyBatteryMorningMax { scores[.bodyBattery] = clampedPercent(battery) }
    if let ratio = input.acuteChronic { scores[.load] = loadComponent(ratio) }
    return scores
}

public func readiness(_ input: ReadinessInput) -> Readiness? {
    typealias C = ReadinessConstants
    let scores = readinessComponents(input)
    guard scores[.hrv] != nil || scores[.sleep] != nil else { return nil }

    let totalWeight = scores.keys.reduce(0) { $0 + $1.weight }
    let weighted = scores.reduce(0) { $0 + $1.value * $1.key.weight }
    let score = Int((weighted / totalWeight).rounded(.toNearestOrAwayFromZero))

    let verdict: ReadinessVerdict
    if score >= C.hardThreshold {
        verdict = .hard
    } else if score >= C.moderateThreshold {
        verdict = .moderate
    } else {
        verdict = .rest
    }
    return Readiness(score: score, partial: scores.count < ReadinessComponent.allCases.count, verdict: verdict)
}

public func bodyBatteryMorningMax(values: [(Date, Int)], sleepEnd: Date) -> Int? {
    let windowEnd = sleepEnd.addingTimeInterval(ReadinessConstants.bodyBatteryWindow)
    return values
        .filter { $0.0 >= sleepEnd && $0.0 <= windowEnd }
        .map(\.1)
        .max()
}
