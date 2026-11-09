import Foundation
import Testing
@testable import Metrics

private let baseline = HRVBaseline(lowUpper: 38, balancedLow: 41, balancedUpper: 53)

private func input(hrv: Double? = 47, sleep: Double? = 80, bb: Double? = 70, load: Double? = 1.0) -> ReadinessInput {
    ReadinessInput(hrvLastNight: hrv, hrvBaseline: baseline, sleepScore: sleep, bodyBatteryMorningMax: bb, acuteChronic: load)
}

private func normalDay() -> ReadinessInput {
    input(hrv: 45.5, sleep: 64, bb: 75, load: 1.5375)
}

@Test func breakdownSumsToDifferenceFromNormal() throws {
    let history = Array(repeating: normalDay(), count: 20)
    let today = input(hrv: 51.5, sleep: 54, bb: 85, load: 1.55)
    let result = try #require(readinessBreakdown(today: today, history: history))
    let normal = try #require(result.normal)
    let sum = result.factors.compactMap(\.points).reduce(0, +)
    #expect(abs(sum - (Double(result.score) - normal)) < 1e-9)
}

@Test func breakdownMatchesMockup() throws {
    let history = Array(repeating: normalDay(), count: 20)
    let today = input(hrv: 51.5, sleep: 54, bb: 85, load: 1.55)
    let result = try #require(readinessBreakdown(today: today, history: history))
    func points(_ component: ReadinessComponent) -> Double? {
        result.factors.first { $0.component == component }?.points
    }
    #expect(abs(try #require(points(.hrv)) - 7.0) < 1e-6)
    #expect(abs(try #require(points(.sleep)) - -2.5) < 1e-6)
    #expect(abs(try #require(points(.bodyBattery)) - 2.0) < 1e-6)
    #expect(abs(try #require(points(.load)) - -0.5) < 1e-6)
    #expect(result.factors.first?.component == .hrv)
}

@Test func breakdownNeedsFourteenDays() throws {
    let history = Array(repeating: normalDay(), count: 13)
    let result = try #require(readinessBreakdown(today: input(), history: history))
    #expect(result.normal == nil)
    for factor in result.factors {
        #expect(factor.normalScore == nil)
        #expect(factor.points == nil)
    }
}

@Test func missingComponentRenormalizesWeights() throws {
    let history = Array(repeating: normalDay(), count: 20)
    let result = try #require(readinessBreakdown(today: input(bb: nil), history: history))
    let present = result.factors.filter { $0.todayScore != nil }
    #expect(present.count == 3)
    #expect(abs(present.map(\.weight).reduce(0, +) - 1) < 1e-9)
    let last = try #require(result.factors.last)
    #expect(last.component == .bodyBattery)
    #expect(last.todayScore == nil)
}

@Test func componentsMatchReadinessAverage() throws {
    let sample = input()
    let scores = readinessComponents(sample)
    let weights: [ReadinessComponent: Double] = [.hrv: 0.35, .sleep: 0.25, .bodyBattery: 0.20, .load: 0.20]
    let weighted = scores.reduce(0) { $0 + $1.value * weights[$1.key]! }
    let total = scores.keys.reduce(0) { $0 + weights[$1]! }
    #expect(Int((weighted / total).rounded(.toNearestOrAwayFromZero)) == readiness(sample)?.score)
}
