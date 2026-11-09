import Foundation
import TrainingCore

public func project(
    _ series: [(Day, Double)],
    today: Day,
    horizonDays: Int,
    softCeiling: Double? = nil,
    target: Double? = nil
) -> Projection? {
    guard horizonDays >= 1 else { return nil }
    let samples: [(x: Double, y: Double)] = series.compactMap { day, value in
        let offset = today.days(until: day)
        guard offset <= 0, offset > -ProjectionConstants.windowDays else { return nil }
        return (Double(offset), value)
    }
    let n = Double(samples.count)
    guard samples.count >= ProjectionConstants.minimumPoints else { return nil }

    let meanX = samples.reduce(0) { $0 + $1.x } / n
    let meanY = samples.reduce(0) { $0 + $1.y } / n
    let sxx = samples.reduce(0) { $0 + ($1.x - meanX) * ($1.x - meanX) }
    guard sxx > 0 else { return nil }
    let sxy = samples.reduce(0) { $0 + ($1.x - meanX) * ($1.y - meanY) }
    let slope = sxy / sxx
    let intercept = meanY - slope * meanX

    let residualSquares = samples.reduce(0) {
        let residual = $1.y - (intercept + slope * $1.x)
        return $0 + residual * residual
    }
    let sigma = (residualSquares / (n - 2)).squareRoot()

    var cursor = intercept
    var points: [ProjectionPoint] = []
    points.reserveCapacity(horizonDays)
    for h in 1...horizonDays {
        let next = cursor + slope
        if let ceiling = softCeiling, slope > 0 {
            let high = max(cursor, next)
            let low = min(cursor, next)
            let above = max(0, high - max(low, ceiling))
            let effective = (high - low) - above * (1 - ProjectionConstants.ceilingFactor)
            cursor += effective
        } else {
            cursor = next
        }
        let halfWidth = ProjectionConstants.bandZ * sigma * (1 + Double(h) / n).squareRoot()
        points.append(ProjectionPoint(
            day: today.adding(days: h),
            mid: cursor,
            low: cursor - halfWidth,
            high: cursor + halfWidth
        ))
    }

    var crossing: Day?
    if let target, slope != 0 {
        let ahead = slope > 0 ? target - intercept : intercept - target
        if abs(ahead) <= ProjectionConstants.targetTolerance * max(1, abs(target)) {
            crossing = today
        } else if ahead > 0 {
            crossing = points.first { slope > 0 ? $0.mid >= target : $0.mid <= target }?.day
        }
    }
    return Projection(points: points, targetCrossing: crossing)
}
