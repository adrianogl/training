import Foundation
import Testing
import TrainingCore
@testable import Insights

struct StrengthPlanTests {
    private func session(_ weekday: Int) -> TrainerStrengthSession {
        TrainerStrengthSession(weekday: weekday, group: .upper, legLoad: .light, name: "Superior")
    }

    private func plan(start: String, validity: StrengthPlanValidity, weekdays: [Int] = [2, 4]) -> StrengthPlan {
        StrengthPlan(objective: .strength, sessions: weekdays.map(session), start: Day(iso: start)!, validity: validity, builder: .trainer)
    }

    @Test func weeks_8_from_tue_24_11_ends_mon_18_01_with_16_sessions() {
        let value = plan(start: "2026-11-24", validity: .weeks(8))
        #expect(value.end == Day(iso: "2027-01-18")!)
        #expect(value.plannedCount() == 16)
        #expect(value.lastSessionDay() == Day(iso: "2027-01-14")!)
    }

    @Test func until_date_end_is_the_date() {
        let value = plan(start: "2026-11-24", validity: .untilDate(Day(iso: "2026-12-20")!))
        #expect(value.end == Day(iso: "2026-12-20")!)
    }

    @Test func until_race_ends_day_before_race() {
        let value = plan(start: "2026-11-24", validity: .untilRace(raceId: "r", raceDay: Day(iso: "2027-03-14")!))
        #expect(value.end == Day(iso: "2027-03-13")!)
    }

    @Test func inactive_after_end() {
        let value = plan(start: "2026-11-24", validity: .weeks(1))
        #expect(value.isActive(on: Day(iso: "2026-11-24")!))
        #expect(value.isActive(on: Day(iso: "2026-11-30")!))
        #expect(!value.isActive(on: Day(iso: "2026-12-01")!))
        #expect(!value.isActive(on: Day(iso: "2026-11-23")!))
    }
}
