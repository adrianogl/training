import Testing
import TrainingCore
@testable import trAIning

@Suite struct RaceTaperTests {
    @Test func planTargetsTwoTaperWeeksFromFourWeekBase() throws {
        let raceDay = Day(iso: "2026-11-22")!
        let raceWeek = raceDay.weekStart
        let firstTaper = raceWeek.adding(days: -7)
        var weekly: [Day: Double] = [firstTaper: 20, raceWeek: 5]
        for offset in 1...4 { weekly[firstTaper.adding(days: -7 * offset)] = 60 }

        let plan = try #require(RaceTaper.plan(raceDay: raceDay, today: Day(iso: "2026-11-13")!, weeklyKm: weekly, longestKm: 20, best: nil))

        #expect(plan.baseKm == 60)
        #expect(plan.weeks.count == 4)
        #expect(plan.weeks[2].targetKm == 60 * RaceTaperConstants.firstWeekShare)
        #expect(plan.weeks[3].isRaceWeek)
        #expect(plan.longestKm == 13)
        #expect(RaceTaper.plan(raceDay: raceDay, today: Day(iso: "2026-11-01")!, weeklyKm: weekly, longestKm: 20, best: nil) == nil)
    }

    @Test func bestHistoryIsTheRaceClosestUnderGoal() {
        let history = [
            TaperHistory(name: "A", reduction: 0.2, deltaToGoal: 60),
            TaperHistory(name: "B", reduction: 0.35, deltaToGoal: -20),
        ]

        #expect(RaceTaper.best(history)?.name == "B")
    }
}
