import Testing
import TrainingCore
@testable import Metrics

private let today = Day(iso: "2026-11-04")!

private func kmLength(_ i: Int, _ total: Double) -> Double {
    let kms = Int((total / 1000).rounded(.up))
    return i < kms - 1 ? 1000 : total - Double(kms - 1) * 1000
}

private func total(_ p: [KmPlan], _ distance: Double) -> Double {
    p.reduce(0) { $0 + $1.pace * kmLength($1.index, distance) / 1000 }
}

@Test func riegelHalfFromTen() { #expect(abs(riegel(seconds: 2700, from: 10_000, to: 21_097.5) - 5958) < 2) }

@Test func predictionIgnoresOldEfforts() {
    let old = Effort(distance: 10_000, seconds: 2700, day: today.adding(days: -Int(RaceConstants.raceEffortWindowDays) - 30), kind: .race)
    #expect(predict(distance: 21_097.5, efforts: [old], on: today) == nil)
    let edge = Effort(distance: 10_000, seconds: 2700, day: today.adding(days: -Int(RaceConstants.raceEffortWindowDays)), kind: .race)
    #expect(predict(distance: 21_097.5, efforts: [edge], on: today) == nil)
}

@Test func predictionWeightsByKindAndAge() {
    let race = Effort(distance: 10_000, seconds: 2700, day: today.adding(days: -30), kind: .race)
    let split = Effort(distance: 5000, seconds: 1200, day: today, kind: .split5k)
    let wRace = 1.0 * (1 - 30.0 / RaceConstants.raceEffortWindowDays)
    let wSplit = 0.7
    let expected = (wRace * riegel(seconds: 2700, from: 10_000, to: 21_097.5)
        + wSplit * riegel(seconds: 1200, from: 5000, to: 21_097.5)) / (wRace + wSplit)
    let p = predict(distance: 21_097.5, efforts: [race, split], on: today)
    #expect(p != nil && abs(p! - expected) < 1e-6)
}

@Test func predictionUsesBestEffortOfEachKind() {
    var efforts = (1...20).map { Effort(distance: 5000, seconds: 1680, day: today.adding(days: -$0), kind: .split5k) }
    efforts.append(Effort(distance: 5000, seconds: 1320, day: today.adding(days: -5), kind: .split5k))
    let p = predict(distance: 5000, efforts: efforts, on: today)
    #expect(p != nil && abs(p! - 1320) < 1)
}

@Test func olderBestEffortBeatsNewerSlowOne() {
    let oldFast = Effort(distance: 5000, seconds: 1320, day: today.adding(days: -60), kind: .split5k)
    let newSlow = Effort(distance: 5000, seconds: 1680, day: today, kind: .split5k)
    let p = predict(distance: 10_000, efforts: [newSlow, oldFast], on: today)
    #expect(p != nil && abs(p! - riegel(seconds: 1320, from: 5000, to: 10_000)) < 1e-6)
    #expect(bestEfforts([newSlow, oldFast], for: 10_000, on: today) == [oldFast])
}

@Test func onePerKindKeepsWeightingAcrossKinds() {
    let race = Effort(distance: 10_000, seconds: 2700, day: today.adding(days: -45), kind: .race)
    let split5k = Effort(distance: 5000, seconds: 1250, day: today.adding(days: -9), kind: .split5k)
    let split1k = Effort(distance: 1000, seconds: 225, day: today.adding(days: -18), kind: .split1k)
    let window = RaceConstants.effortWindowDays
    let weights = [1.0 * (1 - 45.0 / RaceConstants.raceEffortWindowDays), 0.7 * (1 - 9.0 / window), 0.3 * (1 - 18.0 / window)]
    let times = [
        riegel(seconds: 2700, from: 10_000, to: 21_097.5),
        riegel(seconds: 1250, from: 5000, to: 21_097.5),
        riegel(seconds: 225, from: 1000, to: 21_097.5),
    ]
    let expected = zip(weights, times).reduce(0) { $0 + $1.0 * $1.1 } / weights.reduce(0, +)
    let p = predict(distance: 21_097.5, efforts: [race, split5k, split1k], on: today)
    #expect(p != nil && abs(p! - expected) < 1e-6)
}

@Test func predictionIgnoresFutureEfforts() {
    let future = Effort(distance: 10_000, seconds: 2700, day: today.adding(days: 1), kind: .race)
    #expect(predict(distance: 21_097.5, efforts: [future], on: today) == nil)
}

@Test func goalThresholds() {
    #expect(assessGoal(goalSeconds: 6300, predictionSeconds: 6510) == .challenging)
    #expect(assessGoal(goalSeconds: 6000, predictionSeconds: 6510) == .aggressive)
    #expect(assessGoal(goalSeconds: 6500, predictionSeconds: 6510) == .easy)
}

@Test func longRunTargetByDistance() {
    #expect(longRunTarget(raceDistance: 10_000) == 10_000)
    #expect(longRunTarget(raceDistance: 21_097.5) == 21_097.5 * 0.9)
    #expect(longRunTarget(raceDistance: 42_195) == 42_195 * 0.75)
}

@Test func flatStrategyHitsGoal() {
    let p = paceStrategy(goalSeconds: 6300, distance: 21_097.5, profile: nil, manual: [:])
    #expect(p.count == 22)
    #expect(abs(p.reduce(0) { $0 + $1.pace * kmLength($1.index, 21_097.5) / 1000 } - 6300) < 1)
    #expect(p[0].pace - p[10].pace > 4.9 && p[0].label == "aquece" && p.last!.label == "final")
    #expect(p[10].label == "plano" && p[19].label == "final" && p[18].label == "plano")
}

@Test func manualPaceIsKept() {
    let p = paceStrategy(goalSeconds: 6300, distance: 21_097.5, profile: nil, manual: [5: 300])
    #expect(p[5].pace == 300 && p[5].manual)
    #expect(!p[4].manual)
    #expect(abs(total(p, 21_097.5) - 6300) < 1e-6)
}

@Test func profileGradesAndLabels() {
    let profile: [(distance: Double, altitude: Double)] = [(0, 100), (4000, 100), (5000, 150), (6000, 100), (10_000, 100)]
    let p = paceStrategy(goalSeconds: 3000, distance: 10_000, profile: profile, manual: [:])
    #expect(p.count == 10)
    #expect(abs(p[4].grade - 0.05) < 1e-9 && p[4].label == "subida")
    #expect(abs(p[5].grade + 0.05) < 1e-9 && p[5].label == "descida")
    #expect(p[3].label == "plano")
    #expect(p[4].pace > p[3].pace && p[5].pace < p[3].pace)
    #expect(abs(total(p, 10_000) - 3000) < 1e-6)
}

@Test func blockProjectsFutureWeeks() {
    let week = today.weekStart
    var km: [Day: Double] = [:]
    for (i, value) in [20.0, 22, 24, 26, 28, 30].enumerated() {
        km[week.adding(days: -7 * (6 - i))] = value
    }
    km[week] = 12
    let block = raceBlock(raceDay: today.adding(days: 42), today: today, weeklyKm: km)
    #expect(block.count == 12)
    #expect(block.last!.start == today.adding(days: 42).weekStart)
    #expect(block.first!.start == week.adding(days: -35))
    let projected = block.filter(\.projected)
    #expect(projected.count == 6 && projected.allSatisfy { $0.km == 27 })
    #expect(block[5].start == week && block[5].km == 12 && !block[5].projected)
    #expect(block[0].km == 22)
}

@Test func assessGoalRejectsMissingNumbers() {
    #expect(assessGoal(goalSeconds: 6300, predictionSeconds: 0) == nil)
    #expect(assessGoal(goalSeconds: 0, predictionSeconds: 6510) == nil)
    #expect(assessGoal(goalSeconds: .nan, predictionSeconds: 6510) == nil)
}

@Test func strategyClampsGradeToMinettiRange() {
    let wall: [(distance: Double, altitude: Double)] = [(0, 100), (1000, 100), (2000, 900), (5000, 900)]
    let p = paceStrategy(goalSeconds: 1800, distance: 5000, profile: wall, manual: [:])
    #expect(abs(p[1].grade - 0.8) < 1e-9)
    let steep = paceStrategy(goalSeconds: 1800, distance: 5000, profile: [(0, 100), (1000, 100), (2000, 550), (5000, 550)], manual: [:])
    #expect(abs(p[1].pace - steep[1].pace) < 1e-9)
    #expect(abs(total(p, 5000) - 1800) < 1e-6)
}

@Test func strategyIsEmptyWhenManualPacesLeaveNoRoom() {
    let p = paceStrategy(goalSeconds: 1500, distance: 5000, profile: nil, manual: [0: 600, 1: 600, 2: 600])
    #expect(p.isEmpty)
}

@Test func strategyIgnoresManualKmOutsideRace() {
    let p = paceStrategy(goalSeconds: 1500, distance: 5000, profile: nil, manual: [-1: 100, 7: 100])
    #expect(p.count == 5 && p.allSatisfy { !$0.manual })
    #expect(abs(total(p, 5000) - 1500) < 1e-6)
}

@Test func blockForFarRaceIsAllProjected() {
    var km: [Day: Double] = [:]
    for offset in 1...4 { km[today.weekStart.adding(days: -7 * offset)] = 40 }
    let block = raceBlock(raceDay: today.adding(days: 7 * 20), today: today, weeklyKm: km)
    #expect(block.count == 12)
    #expect(block.allSatisfy { $0.projected && $0.km == 40 })
}

@Test func blockForPastRaceIsAllHistory() {
    let race = today.adding(days: -30)
    var km: [Day: Double] = [:]
    km[race.weekStart] = 21
    let block = raceBlock(raceDay: race, today: today, weeklyKm: km)
    #expect(block.allSatisfy { !$0.projected })
    #expect(block.last?.start == race.weekStart && block.last?.km == 21)
}

@Test func strategyRejectsNonPositiveManualPace() {
    let manual = Dictionary(uniqueKeysWithValues: (0..<5).map { ($0, $0 == 2 ? 0.0 : 300.0) })
    #expect(paceStrategy(goalSeconds: 1500, distance: 5000, profile: nil, manual: manual).isEmpty)
}

@Test func raceEffortKeepsWeightUntil365Days() {
    let race = Effort(distance: 10_000, seconds: 2700, day: today.adding(days: -300), kind: .race)
    let split = Effort(distance: 5000, seconds: 1200, day: today.adding(days: -300), kind: .split5k)
    #expect(predict(distance: 10_000, efforts: [race], on: today) != nil)
    #expect(predict(distance: 10_000, efforts: [split], on: today) == nil)
}
