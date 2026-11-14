import Foundation
import Storage
import TrainingCore

enum RaceTaper {
    private typealias C = RaceTaperConstants

    static func plan(raceDay: Day, today: Day, weeklyKm: [Day: Double], longestKm: Double, best: TaperHistory?) -> TaperPlan? {
        let daysLeft = today.days(until: raceDay)
        guard daysLeft > 0, daysLeft <= C.windowDays else { return nil }
        let raceWeek = raceDay.weekStart
        let firstTaperWeek = raceWeek.adding(days: -C.daysPerWeek)
        let baseWeeks = (1...C.baseWeeks).map { firstTaperWeek.adding(days: -C.daysPerWeek * $0) }
        let base = baseWeeks.map { weeklyKm[$0] ?? 0 }.reduce(0, +) / Double(C.baseWeeks)
        let previous = [firstTaperWeek.adding(days: -2 * C.daysPerWeek), firstTaperWeek.adding(days: -C.daysPerWeek)]
        var weeks = previous.map { TaperWeek(start: $0, doneKm: weeklyKm[$0] ?? 0, targetKm: nil, isRaceWeek: false) }
        weeks.append(TaperWeek(start: firstTaperWeek, doneKm: weeklyKm[firstTaperWeek] ?? 0, targetKm: base * C.firstWeekShare, isRaceWeek: false))
        weeks.append(TaperWeek(start: raceWeek, doneKm: weeklyKm[raceWeek] ?? 0, targetKm: base * C.raceWeekShare, isRaceWeek: true))
        let longest = (longestKm * C.longShare).rounded()
        return TaperPlan(
            daysLeft: daysLeft,
            baseKm: base,
            weeks: weeks,
            longestKm: longest,
            advice: String(format: C.adviceFormat, TodayText.decimal(longest, fractionDigits: 0)),
            best: best
        )
    }

    static func history(races: [RaceRecord], runs: [ActivityRecord]) -> [TaperHistory] {
        races.compactMap { race in
            guard let resultId = race.resultActivityId, let goal = race.goalSeconds, let raceDay = Day(iso: race.day),
                  let result = runs.first(where: { $0.activityId == resultId }), let seconds = result.movingDuration ?? result.duration else { return nil }
            let km = { (from: Day, to: Day) -> Double in
                runs.filter { run in
                    guard let day = run.localDay.flatMap(Day.init(iso:)) else { return false }
                    return from <= day && day < to
                }
                .reduce(0) { $0 + ($1.distance ?? 0) } / C.metersPerKm
            }
            let taperStart = raceDay.adding(days: -C.historyWindowDays)
            let taper = km(taperStart, raceDay)
            let base = km(taperStart.adding(days: -C.historyBaseDays), taperStart) / Double(C.historyBaseDays) * Double(C.historyWindowDays)
            guard base > 0 else { return nil }
            return TaperHistory(name: race.name, reduction: 1 - taper / base, deltaToGoal: seconds - goal)
        }
    }

    static func best(_ history: [TaperHistory]) -> TaperHistory? {
        history.min { $0.deltaToGoal < $1.deltaToGoal }
    }
}
