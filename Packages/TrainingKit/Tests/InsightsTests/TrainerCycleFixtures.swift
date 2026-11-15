import Foundation
import TrainingCore
import WorkoutAnalysis
@testable import Insights

let monday = Day(year: 2026, month: 11, day: 9)
let now = Date(timeIntervalSince1970: 1_800_000_000)
let halfMarathon = TrainerTarget(kind: .race, name: "Meia", date: monday.adding(days: 12 * 7 + 5), distanceMeters: 21_097.5, goalSeconds: 5_700)
let raceDay = halfMarathon.date

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
