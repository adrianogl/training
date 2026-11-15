import Foundation
import TrainingCore
import WorkoutAnalysis
@testable import Insights

let monday = Day(year: 2026, month: 11, day: 9)
let now = Date(timeIntervalSince1970: 1_800_000_000)
let halfMarathon = TrainerTarget(kind: .race, name: "Meia", date: monday.adding(days: 12 * 7 + 5), distanceMeters: 21_097.5, goalSeconds: 5_700)
let raceDay = halfMarathon.date!

func makeHistory() -> TrainerHistory {
    var runs: [TrainerRun] = []
    for week in 1...4 {
        let start = monday.adding(days: -7 * week)
        let base = Int64(week * 10)
        runs.append(TrainerRun(activityId: base + 1, day: start, meters: 10_000, seconds: 3_000, kind: .easy))
        runs.append(TrainerRun(activityId: base + 2, day: start.adding(days: 1), meters: 12_000, seconds: 3_000, kind: .tempo))
        runs.append(TrainerRun(activityId: base + 3, day: start.adding(days: 3), meters: 10_000, seconds: 3_000, kind: .easy))
        runs.append(TrainerRun(activityId: base + 4, day: start.adding(days: 5), meters: 18_000, seconds: 18 * 310, kind: .long))
    }
    return TrainerHistory(runs: runs, readiness: [:], predictions: [10_000: 2_460, 5_000: 1_170])
}

func makePlan() -> TrainerPlan {
    let peak = 80_000.0
    return TrainerEngine.create(
        target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], history: makeHistory(),
        today: monday, now: now, startMeters: (peak * 0.75 / 1_000).rounded() * 1_000, peakMeters: peak
    )
}

func history(
    _ plan: TrainerPlan, done: Double = 0, readiness: Bool = true, readinessDrop: Int = 0, raceSeconds: Double? = nil
) -> TrainerHistory {
    var runs: [TrainerRun] = []
    if done > 0 {
        for (offset, workout) in plan.workouts.sorted(by: { $0.day < $1.day }).enumerated() where workout.totalMeters > 0 {
            let meters = workout.totalMeters * done
            let pace = workout.paceLow ?? plan.paces.easy
            let seconds = workout.kind == .race ? raceSeconds ?? meters / 1_000 * pace : meters / 1_000 * pace
            runs.append(TrainerRun(activityId: Int64(1_000 + offset), day: workout.day, meters: meters, seconds: seconds, kind: runKind(workout.kind)))
        }
    }
    if let raceSeconds, !runs.contains(where: { $0.day == raceDay && $0.kind == .race }) {
        runs.append(TrainerRun(activityId: 999, day: raceDay, meters: 21_097.5, seconds: raceSeconds, kind: .race))
    }
    let first = plan.weeks.first?.start ?? monday
    let span = max(1, first.days(until: plan.weeks.last?.start.adding(days: 6) ?? first))
    var values: [Day: Int] = [:]
    if readiness {
        for offset in 0...span {
            values[first.adding(days: offset)] = 72 - Int((Double(readinessDrop * offset) / Double(span)).rounded())
        }
    }
    var predictionSeries: [Day: [Double: Double]] = [:]
    for (offset, week) in plan.weeks.enumerated() {
        predictionSeries[week.start] = [10_000: 2_460 - Double(offset)]
    }
    return TrainerHistory(runs: runs, readiness: values, predictions: [10_000: 2_460], predictionSeries: predictionSeries)
}

func runKind(_ kind: TrainerDayKind) -> RunKind {
    switch kind {
    case .long: .long
    case .threshold: .tempo
    case .vo2max: .intervals
    case .race: .race
    default: .easy
    }
}
