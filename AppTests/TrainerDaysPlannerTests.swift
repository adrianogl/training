import Insights
import Testing
@testable import trAIning

@Suite struct TrainerDaysPlannerTests {
    @Test func runsRangeShrinksWithTheOffDays() {
        #expect(TrainerDaysPlanner.runsRange(.standard) == 3...6)
        #expect(TrainerDaysPlanner.runsRange(TrainerDayPreference(runs: 7, optional: false, offDays: [], longDay: 6)) == 3...7)
        #expect(TrainerDaysPlanner.runsRange(TrainerDayPreference(runs: 3, optional: false, offDays: [1, 3, 5, 7], longDay: 6)) == 3...3)
    }

    @Test func markingAnOffDayLowersTheRunsWhenTheyNoLongerFit() {
        let next = TrainerDaysPlanner.togglingOff(.standard, weekday: 3)

        #expect(next.offDays == [3, 7])
        #expect(next.runs == 5)
        #expect(TrainerDaysPlanner.togglingOff(next, weekday: 3).offDays == [7])
    }

    @Test func theLongDayAndTheLastThreeRunDaysCannotBecomeOff() {
        let full = TrainerDayPreference(runs: 3, optional: false, offDays: [1, 3, 5, 7], longDay: 6)

        #expect(TrainerDaysPlanner.togglingOff(.standard, weekday: 6) == .standard)
        #expect(TrainerDaysPlanner.togglingOff(full, weekday: 2) == full)
    }

    @Test func choosingTheLongDayClearsItFromTheOffDays() {
        let next = TrainerDaysPlanner.choosingLong(.standard, weekday: 7)

        #expect(next.longDay == 7)
        #expect(next.offDays.isEmpty)
    }

    @Test func settingRunsStaysInsideTheRange() {
        #expect(TrainerDaysPlanner.settingRuns(.standard, runs: 9).runs == 6)
        #expect(TrainerDaysPlanner.settingRuns(.standard, runs: 1).runs == 3)
        #expect(TrainerDaysPlanner.settingRuns(.standard, runs: 4).runs == 4)
    }

    @Test func warnedDaysJoinEveryWarning() {
        let warnings = [TrainerDayWarning(days: [5, 6], text: "a"), TrainerDayWarning(days: [], text: "b"), TrainerDayWarning(days: [4], text: "c")]

        #expect(TrainerDaysPlanner.warnedDays(warnings) == [4, 5, 6])
    }

    @Test func textsDescribeTheWeek() {
        #expect(TrainerDaysText.runsDetail(runs: 6, optional: true) == "5 fixas + 1 opcional")
        #expect(TrainerDaysText.runsDetail(runs: 4, optional: false) == "4 fixas")
        #expect(TrainerDaysText.summary(peakMeters: 70_000, meters: 70_400, quality: 2, alternates: false) == "Pico de 70 km · 2 de qualidade")
        #expect(TrainerDaysText.summary(peakMeters: 19_000, meters: 33_000, quality: 1, alternates: true) == "Pico de 19 km, dias somam 33 km · 1 de qualidade, alternando limiar e VO2")
        #expect(TrainerDaysText.summary(peakMeters: 63_000, meters: 63_000, quality: 1, alternates: true) == "Pico de 63 km · 1 de qualidade, alternando limiar e VO2")
        #expect(TrainerDaysText.kilometers(0) == "—")
        #expect(TrainerDaysText.warningsCount(2) == "2 avisos")
    }
}
