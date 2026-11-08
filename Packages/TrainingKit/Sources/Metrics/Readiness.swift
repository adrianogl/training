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

public func readiness(_ input: ReadinessInput) -> Readiness? {
    typealias C = ReadinessConstants
    var hrv: Double?
    if let value = input.hrvLastNight, let baseline = input.hrvBaseline {
        hrv = hrvComponent(value, baseline)
    }
    let sleep = input.sleepScore.map(clampedPercent)
    guard hrv != nil || sleep != nil else { return nil }

    let components: [(score: Double?, weight: Double)] = [
        (hrv, C.hrvWeight),
        (sleep, C.sleepWeight),
        (input.bodyBatteryMorningMax.map(clampedPercent), C.bodyBatteryWeight),
        (input.acuteChronic.map(loadComponent), C.loadWeight),
    ]
    let present = components.compactMap { component in component.score.map { ($0, component.weight) } }
    let totalWeight = present.reduce(0) { $0 + $1.1 }
    let weighted = present.reduce(0) { $0 + $1.0 * $1.1 }
    let score = Int((weighted / totalWeight).rounded(.toNearestOrAwayFromZero))

    let verdict: ReadinessVerdict
    if score >= C.hardThreshold {
        verdict = .hard
    } else if score >= C.moderateThreshold {
        verdict = .moderate
    } else {
        verdict = .rest
    }
    return Readiness(score: score, partial: present.count < components.count, verdict: verdict)
}

public func bodyBatteryMorningMax(values: [(Date, Int)], sleepEnd: Date) -> Int? {
    let windowEnd = sleepEnd.addingTimeInterval(ReadinessConstants.bodyBatteryWindow)
    return values
        .filter { $0.0 >= sleepEnd && $0.0 <= windowEnd }
        .map(\.1)
        .max()
}
