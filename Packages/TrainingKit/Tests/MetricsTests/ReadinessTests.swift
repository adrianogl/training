import Foundation
import Testing
@testable import Metrics

private let b = HRVBaseline(lowUpper: 38, balancedLow: 41, balancedUpper: 53)

private func input(hrv: Double? = 47, baseline: HRVBaseline? = b, sleep: Double? = 80, bb: Double? = 70, load: Double? = 1.0) -> ReadinessInput {
    ReadinessInput(hrvLastNight: hrv, hrvBaseline: baseline, sleepScore: sleep, bodyBatteryMorningMax: bb, acuteChronic: load)
}

@Test func hrvRamps() {
    #expect(hrvComponent(30, b) == 0)
    #expect(abs(hrvComponent(39.5, b) - 30) < 1e-9)
    #expect(hrvComponent(41, b) == 60)
    #expect(abs(hrvComponent(47, b) - 80) < 1e-9)
    #expect(hrvComponent(60, b) == 100)
}

@Test func hrvDegenerateBaselineDoesNotDivideByZero() {
    let flat = HRVBaseline(lowUpper: 40, balancedLow: 40, balancedUpper: 40)
    #expect(hrvComponent(39, flat) == 0)
    #expect(hrvComponent(40, flat) == 60)
    #expect(hrvComponent(41, flat) == 100)
}

@Test func loadRamps() {
    #expect(loadComponent(1.0) == 100 && loadComponent(0.5) == 0 && loadComponent(1.8) == 0)
    #expect(abs(loadComponent(1.55) - 50) < 1e-9)
    #expect(abs(loadComponent(0.65) - 50) < 1e-9)
    #expect(loadComponent(0.8) == 100 && loadComponent(1.3) == 100)
    #expect(loadComponent(0.2) == 0 && loadComponent(2.5) == 0)
}

@Test func fullScoreAndVerdict() {
    let r = readiness(input())!
    #expect(r.score == 82 && r.verdict == .hard && !r.partial)
}

@Test func redistributesWhenBodyBatteryMissing() {
    let r = readiness(input(bb: nil))!
    #expect(r.partial && r.score == 85)
}

@Test func missingBaselineDropsHRV() {
    let r = readiness(input(baseline: nil))!
    #expect(r.partial)
    #expect(r.score == 83)
}

@Test func noNightDataMeansNoScore() {
    #expect(readiness(input(hrv: nil, sleep: nil, bb: 90)) == nil)
    #expect(readiness(input(baseline: nil, sleep: nil, bb: 90)) == nil)
}

@Test func sleepOnlyIsPartial() {
    let r = readiness(input(hrv: nil, bb: nil, load: nil))!
    #expect(r.partial && r.score == 80)
}

@Test func clampsSleepAndBodyBattery() {
    let r = readiness(input(hrv: nil, sleep: 150, bb: -20, load: nil))!
    #expect(r.score == 56)
}

@Test func verdictThresholds() {
    func verdict(forSleep s: Double) -> ReadinessVerdict {
        readiness(input(hrv: nil, sleep: s, bb: nil, load: nil))!.verdict
    }
    #expect(verdict(forSleep: 39) == .rest)
    #expect(verdict(forSleep: 40) == .moderate)
    #expect(verdict(forSleep: 69) == .moderate)
    #expect(verdict(forSleep: 70) == .hard)
}

@Test func bodyBatteryMorningMaxUsesThreeHourWindow() {
    let end = Date(timeIntervalSince1970: 1_800_000_000)
    let values: [(Date, Int)] = [
        (end.addingTimeInterval(-60), 99),
        (end, 40),
        (end.addingTimeInterval(3600), 65),
        (end.addingTimeInterval(3 * 3600), 58),
        (end.addingTimeInterval(3 * 3600 + 1), 95),
    ]
    #expect(bodyBatteryMorningMax(values: values, sleepEnd: end) == 65)
    #expect(bodyBatteryMorningMax(values: [(end.addingTimeInterval(-1), 80)], sleepEnd: end) == nil)
    #expect(bodyBatteryMorningMax(values: [], sleepEnd: end) == nil)
}
