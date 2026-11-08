import Testing
import TrainingCore
@testable import Metrics

private let start = Day(iso: "2026-01-01")!

@Test func ewmaWithConstantLoad() {
    let loads = Dictionary(uniqueKeysWithValues: (0..<100).map { (start.adding(days: $0), 100.0) })
    let p = fitnessFatigueForm(dailyLoad: loads, from: start, to: Day(iso: "2026-04-10")!)
    #expect(p.count == 100)
    #expect(abs(p.first!.fitness - 100.0 / 42) < 1e-9 && abs(p.first!.fatigue - 100.0 / 7) < 1e-9)
    #expect(p.first!.form == 0)
    #expect(p.last!.fatigue > 99 && p.last!.fitness < p.last!.fatigue)
}

@Test func formUsesPreviousDayState() {
    let loads = [start: 100.0]
    let p = fitnessFatigueForm(dailyLoad: loads, from: start, to: start.adding(days: 1))
    #expect(abs(p[1].form - (100.0 / 42 - 100.0 / 7)) < 1e-9)
}

@Test func emptyRangeReturnsNoPoints() {
    #expect(fitnessFatigueForm(dailyLoad: [:], from: start.adding(days: 1), to: start).isEmpty)
}

@Test func acuteChronic() {
    var loads: [Day: Double] = [:]
    let on = start.adding(days: 27)
    for i in 0..<7 { loads[on.adding(days: -i)] = 100 }
    for i in 7..<28 { loads[on.adding(days: -i)] = 50 }
    let ratio = acuteChronicRatio(dailyLoad: loads, on: on)!
    #expect(abs(ratio - 1.6) < 1e-9)
}

@Test func acuteChronicNilWithoutHistory() {
    #expect(acuteChronicRatio(dailyLoad: [:], on: start) == nil)
    #expect(acuteChronicRatio(dailyLoad: [start.adding(days: -28): 100], on: start) == nil)
}

@Test func focusSplitsLoadByZoneTime() {
    let f = loadFocus([(load: 100, zoneSeconds: [0, 600, 300, 100, 0])])!
    #expect(abs(f.lowAerobic - 0.6) < 1e-9 && abs(f.highAerobic - 0.4) < 1e-9 && f.anaerobic == 0)
}

@Test func focusSumsAcrossItemsAndSumsToOne() {
    let f = loadFocus([
        (load: 100, zoneSeconds: [100, 0, 0, 0, 0]),
        (load: 100, zoneSeconds: [0, 0, 0, 0, 50]),
        (load: 100, zoneSeconds: [0, 0, 100, 0, 0]),
    ])!
    #expect(abs(f.lowAerobic - 1.0 / 3) < 1e-9)
    #expect(abs(f.highAerobic - 1.0 / 3) < 1e-9)
    #expect(abs(f.anaerobic - 1.0 / 3) < 1e-9)
}

@Test func focusIgnoresItemsWithoutZoneTimeOrLoad() {
    #expect(loadFocus([(load: 100, zoneSeconds: [0, 0, 0, 0, 0]), (load: 0, zoneSeconds: [1, 1, 1, 1, 1])]) == nil)
    #expect(loadFocus([]) == nil)
    let f = loadFocus([(load: 100, zoneSeconds: [0, 0, 0, 0, 0]), (load: 50, zoneSeconds: [10, 0, 0, 0, 0])])!
    #expect(f.lowAerobic == 1)
}

@Test func focusTargetRanges() {
    #expect(LoadFocus.target.low == 0.60...0.75)
    #expect(LoadFocus.target.high == 0.20...0.35)
    #expect(LoadFocus.target.anaerobic == 0.05...0.10)
}
