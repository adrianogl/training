import Foundation
import GarminAPI
import Insights
import Reports
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TodayBlocksTests {
    private static let today = Day(iso: "2026-11-15")!

    private static func plan(_ title: String, day: Day = today) -> PlannedWorkout {
        PlannedWorkout(id: 1, day: day.iso, title: title, estimatedSeconds: 3_000, estimatedMeters: 10_000, steps: [])
    }

    private static func row(_ kind: TrainerDayKind, day: Day = today, strength: [TrainerStrengthLine] = []) -> TrainerDayRow {
        let workout = TrainerWorkout(day: day, kind: kind, title: "Treino", totalMeters: kind == .off ? 0 : 12_000, steps: [], rationale: "")
        return TrainerDayRow(workout: workout, status: .planned, run: nil, isChanged: false, strength: strength)
    }

    @Test func shownWeekClosesFromSundayToTuesday() {
        let sunday = WeeklyReportBuilder.shownWeek(today: Day(iso: "2026-11-15")!)
        #expect(sunday == ShownWeek(start: Day(iso: "2026-11-09")!, isCurrent: true, isClosed: true))
        let tuesday = WeeklyReportBuilder.shownWeek(today: Day(iso: "2026-11-17")!)
        #expect(tuesday == ShownWeek(start: Day(iso: "2026-11-09")!, isCurrent: false, isClosed: true))
        let friday = WeeklyReportBuilder.shownWeek(today: Day(iso: "2026-11-13")!)
        #expect(friday == ShownWeek(start: Day(iso: "2026-11-09")!, isCurrent: true, isClosed: false))
    }

    @Test func garminPlanWinsOverTrainer() {
        let strength = [TrainerStrengthLine(id: UUID(), name: "Superiores", isDone: false)]
        let pick = TodayWorkoutPicker.pick(garminToday: Self.plan("Intervalado"), trainerToday: Self.row(.threshold, strength: strength), garminTomorrow: nil, trainerTomorrow: nil)
        #expect(pick?.today == .garmin(Self.plan("Intervalado")))
        #expect(pick?.tomorrow == nil)
        #expect(pick?.strength == strength)
    }

    @Test func trainerIsUsedWithoutGarminPlan() {
        let row = Self.row(.easy)
        let pick = TodayWorkoutPicker.pick(garminToday: nil, trainerToday: row, garminTomorrow: Self.plan("Longão"), trainerTomorrow: nil)
        #expect(pick?.today == .trainer(row))
        #expect(pick?.tomorrow == nil)
    }

    @Test func restDayShowsTomorrowPreferringGarmin() {
        let tomorrow = Self.today.adding(days: 1)
        let pick = TodayWorkoutPicker.pick(
            garminToday: nil, trainerToday: Self.row(.off),
            garminTomorrow: Self.plan("Rodagem", day: tomorrow), trainerTomorrow: Self.row(.easy, day: tomorrow)
        )
        #expect(pick?.today == nil)
        #expect(pick?.tomorrow == .garmin(Self.plan("Rodagem", day: tomorrow)))

        let trainerOnly = TodayWorkoutPicker.pick(garminToday: nil, trainerToday: Self.row(.off), garminTomorrow: nil, trainerTomorrow: Self.row(.easy, day: tomorrow))
        #expect(trainerOnly?.tomorrow == .trainer(Self.row(.easy, day: tomorrow)))

        let restAfterRest = TodayWorkoutPicker.pick(garminToday: nil, trainerToday: Self.row(.off), garminTomorrow: nil, trainerTomorrow: Self.row(.off, day: tomorrow))
        #expect(restAfterRest == TodayWorkoutPick(today: nil, tomorrow: nil))
    }

    @Test func nothingPlannedHidesTheCard() {
        #expect(TodayWorkoutPicker.pick(garminToday: nil, trainerToday: nil, garminTomorrow: nil, trainerTomorrow: nil) == nil)
        #expect(TodayWorkoutPicker.pick(garminToday: nil, trainerToday: nil, garminTomorrow: Self.plan("Longão"), trainerTomorrow: nil)?.tomorrow == .garmin(Self.plan("Longão")))
    }

    @Test func overloadLineListsOnlyFlaggedSignals() {
        let alert = OverloadAlert(days: 3, restingNow: 54, restingBase: 48, hrvNow: 60, hrvBase: 62, ratio: 1.42, restingHigh: true, hrvLow: false, loadHigh: true)
        #expect(OverloadText.headline(alert) == "Sobrecarga há 3 dias")
        #expect(OverloadText.flaggedLine(alert) == "FC de repouso 54 (base 48) · carga 1,4")
    }

    @Test func compactLastRunLine() {
        let run = LastRunSummary(
            activityId: 1, title: "Corrida", dateText: "sáb 14/11", kilometers: 12.7, paceSeconds: 275, averageHeartRate: 165,
            evolution: nil, evolutionOnDevice: false, notice: nil, score: 76, kind: .long, fadeKm: 11
        )
        #expect(LastRunBuilder.compactTitle(run) == "Longão · 12,7 km")
        #expect(LastRunBuilder.compactLine(run, plannedKm: 19) == "4:35/km · FC 165 · queda no km 11 · 67% do plano")
        #expect(LastRunBuilder.compactLine(run, plannedKm: nil) == "4:35/km · FC 165 · queda no km 11")
    }

    @Test func outlookKeepsFiveTenAndHalf() {
        let predictions = [
            Prediction(label: "42,2 km", seconds: 11_000),
            Prediction(label: "10 km", seconds: 2_425),
            Prediction(label: "5 km", seconds: 1_171),
            Prediction(label: "21,1 km", seconds: nil),
        ]
        #expect(TodayOutlookText.predictions(predictions).map(\.label) == ["5 km", "10 km"])
    }

    @Test func goalStatusShowsGapOrAhead() {
        func goal(gap: Double?) -> GoalSnapshot {
            GoalSnapshot(
                id: UUID(), kind: .time, distanceKm: 10, targetSeconds: 2_400, deadline: nil, paceSecondsPerKm: nil,
                progress: .time(TimeGoalProgress(todaySeconds: 2_425, gapSeconds: gap, crossing: .noGoal, achievedOn: nil))
            )
        }
        #expect(TodayOutlookText.goalStatus(goal(gap: 25)) == TodayGoalStatus(text: "faltam 0:25", good: false))
        #expect(TodayOutlookText.goalStatus(goal(gap: -3)) == TodayGoalStatus(text: "previsão abaixo", good: true))
        #expect(TodayOutlookText.goalStatus(goal(gap: nil)) == nil)
        #expect(TodayOutlookText.goalToday(goal(gap: 25)) == "hoje 40:25")
    }
}
