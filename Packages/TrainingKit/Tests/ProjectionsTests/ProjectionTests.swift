import Testing
import TrainingCore
@testable import Projections

private let today = Day(year: 2026, month: 11, day: 1)

private func linearSeries(count: Int = 90, start: Double = 40, slope: Double = 0.1) -> [(Day, Double)] {
    (0..<count).map { (today.adding(days: -(count - 1) + $0), start + Double($0) * slope) }
}

private func noisySeries() -> [(Day, Double)] {
    let pattern = [1.0, -2.0, 0.5, 2.0, -1.5, 0.0, 1.5, -0.5]
    return (0..<90).map { i in
        (today.adding(days: -89 + i), 40 + Double(i) * 0.1 + pattern[i % pattern.count])
    }
}

@Test func linearSeriesProjectsLine() {
    let p = project(linearSeries(), today: today, horizonDays: 30)!
    #expect(p.points.count == 30)
    #expect(p.points.first!.day == today.adding(days: 1))
    #expect(abs(p.points.last!.mid - 51.9) < 0.01)
    #expect(p.points.last!.high - p.points.last!.low < 0.01)
}

@Test func bandWidensWithHorizon() {
    let p = project(noisySeries(), today: today, horizonDays: 60)!
    let first = p.points[0]
    let last = p.points[59]
    #expect(first.high - first.low > 0)
    #expect(last.high - last.low > first.high - first.low)
}

@Test func tooFewPointsReturnsNil() {
    #expect(project(Array(linearSeries().suffix(9)), today: today, horizonDays: 30) == nil)
    #expect(project(Array(linearSeries().suffix(10)), today: today, horizonDays: 30) != nil)
}

@Test func findsTargetCrossing() {
    let s = (0..<90).map { (today.adding(days: -89 + $0), 6510.0 - 2 * Double($0 - 89)) }
    let p = project(s, today: today, horizonDays: 120, target: 6300)!
    #expect(p.targetCrossing == today.adding(days: 105))
}

@Test func softCeilingSlowsGrowth() {
    let free = project(linearSeries(), today: today, horizonDays: 60)!
    let capped = project(linearSeries(), today: today, horizonDays: 60, softCeiling: 52)!
    #expect(abs(free.points.last!.mid - 54.9) < 0.01)
    #expect(abs(capped.points.last!.mid - 53.45) < 0.01)
    #expect(capped.points[19].mid == free.points[19].mid)
}

@Test func zeroHorizonReturnsNil() {
    #expect(project(linearSeries(), today: today, horizonDays: 0) == nil)
}

@Test func pointsOlderThanWindowAreIgnored() {
    var s = linearSeries()
    s += (0..<30).map { (today.adding(days: -200 + $0), 1000.0) }
    let p = project(s, today: today, horizonDays: 30)!
    #expect(abs(p.points.last!.mid - 51.9) < 0.01)
}

@Test func trendAwayFromTargetHasNoCrossing() {
    let p = project(linearSeries(), today: today, horizonDays: 60, target: 30)!
    #expect(p.targetCrossing == nil)
}

@Test func sameDayPointsReturnNil() {
    let s = (0..<20).map { (today, 40.0 + Double($0)) }
    #expect(project(s, today: today, horizonDays: 30) == nil)
}

@Test func softCeilingDoesNotSlowDecline() {
    let series = linearSeries(start: 80, slope: -0.1)
    let free = project(series, today: today, horizonDays: 60)!
    let capped = project(series, today: today, horizonDays: 60, softCeiling: 52)!
    for (a, b) in zip(free.points, capped.points) {
        #expect(abs(a.mid - b.mid) < 1e-9)
    }
}
