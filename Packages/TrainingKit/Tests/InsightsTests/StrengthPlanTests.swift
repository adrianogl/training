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

struct StrengthPlanProgressTests {
    private func session(_ weekday: Int) -> TrainerStrengthSession {
        TrainerStrengthSession(weekday: weekday, group: .mobility, legLoad: .light, name: "Mobilidade")
    }

    private func plan(start: String, validity: StrengthPlanValidity, weekdays: [Int] = [2, 4]) -> StrengthPlan {
        StrengthPlan(objective: .mobility, sessions: weekdays.map(session), start: Day(iso: start)!, validity: validity, builder: .trainer)
    }

    @Test func repeat_plan_starts_next_training_day_same_duration() {
        var ended = plan(start: "2026-11-24", validity: .weeks(8))
        ended.endedNotifiedAt = .now
        let repeated = ended.repeated(after: Day(iso: "2027-01-22")!)
        #expect(repeated.start == Day(iso: "2027-01-26")!)
        #expect(repeated.validity == .weeks(8))
        #expect(repeated.sessions.map(\.weekday) == [2, 4])
        #expect(repeated.objective == .mobility)
        #expect(repeated.id != ended.id)
        #expect(repeated.endedNotifiedAt == nil)
        #expect(!repeated.migrated)

        let dated = plan(start: "2026-11-24", validity: .untilDate(Day(iso: "2026-12-07")!))
        let again = dated.repeated(after: Day(iso: "2026-12-10")!)
        #expect(again.start == Day(iso: "2026-12-15")!)
        #expect(again.validity == .untilDate(Day(iso: "2026-12-28")!))

        let race = plan(start: "2026-11-24", validity: .untilRace(raceId: "r", raceDay: Day(iso: "2026-12-08")!))
        let raceAgain = race.repeated(after: Day(iso: "2026-12-08")!)
        #expect(raceAgain.start == Day(iso: "2026-12-10")!)
        #expect(raceAgain.validity == .untilDate(Day(iso: "2026-12-23")!))
    }

    @Test func week_and_done_count_follow_validity() {
        let value = plan(start: "2026-11-24", validity: .weeks(8))
        #expect(value.totalWeeks == 8)
        #expect(value.week(on: Day(iso: "2026-12-08")!) == 3)
        #expect(value.week(on: Day(iso: "2026-11-01")!) == 1)
        #expect(value.week(on: Day(iso: "2027-03-01")!) == 8)
        let done: Set<Day> = [Day(iso: "2026-11-24")!, Day(iso: "2026-11-25")!, Day(iso: "2026-11-26")!, Day(iso: "2026-11-17")!]
        #expect(value.doneCount(doneDays: done) == 2)
    }

    @Test func first_session_day_is_inclusive() {
        #expect(StrengthPlan.firstSessionDay(weekdays: [2, 4], from: Day(iso: "2026-11-20")!) == Day(iso: "2026-11-24")!)
        #expect(StrengthPlan.firstSessionDay(weekdays: [2, 4], from: Day(iso: "2026-11-24")!) == Day(iso: "2026-11-24")!)
        #expect(StrengthPlan.firstSessionDay(weekdays: [], from: Day(iso: "2026-11-24")!) == nil)
    }
}
