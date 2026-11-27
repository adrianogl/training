import Insights
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import trAIning

struct WorkoutPrescriptionBuilderTests {
    private func row(kind: TrainerDayKind, rationale: String = "Estimula o limiar.", method: TrainerMethod? = nil, runId: Int64? = 42) -> TrainerDayRow {
        let day = Day(iso: "2026-11-24") ?? Day.today()
        let workout = TrainerWorkout(
            day: day, kind: kind, title: "Tiros", totalMeters: 10_000, steps: [],
            paceLow: 260, paceHigh: 270, rationale: rationale, method: method
        )
        let run = runId.map { TrainerRun(activityId: $0, day: day, meters: 10_240, seconds: 3_000, kind: .intervals) }
        return TrainerDayRow(workout: workout, status: .done, run: run, isChanged: false)
    }

    @Test func runOnPlannedDayShowsPlannedPaceAndDone() throws {
        let prescription = try #require(WorkoutPrescriptionBuilder.prescription(row: row(kind: .threshold), activityId: 42, isRun: true, doneMeters: 10_240))
        #expect(prescription.iso == "2026-11-24")
        #expect(prescription.numbers.map(\.label) == ["planejado", "pace dos tiros", "feito"])
        #expect(prescription.numbers.first?.value == "10 km")
        #expect(prescription.numbers[1].value == "4:20–4:30/km")
        #expect(prescription.rationale == "Estimula o limiar.")
    }

    @Test func easyRunUsesPlainPaceLabel() throws {
        let prescription = try #require(WorkoutPrescriptionBuilder.prescription(row: row(kind: .easy), activityId: 42, isRun: true, doneMeters: nil))
        #expect(prescription.numbers.map(\.label) == ["planejado", "pace"])
    }

    @Test func emptyRationaleHidesWhy() throws {
        let prescription = try #require(WorkoutPrescriptionBuilder.prescription(row: row(kind: .easy, rationale: "  "), activityId: 42, isRun: true, doneMeters: 8_000))
        #expect(prescription.rationale == nil)
    }

    @Test func noPrescriptionWithoutPlanRestDayOrNonRun() {
        #expect(WorkoutPrescriptionBuilder.prescription(row: nil, activityId: 42, isRun: true, doneMeters: 8_000) == nil)
        #expect(WorkoutPrescriptionBuilder.prescription(row: row(kind: .off), activityId: 42, isRun: true, doneMeters: 8_000) == nil)
        #expect(WorkoutPrescriptionBuilder.prescription(row: row(kind: .threshold), activityId: 42, isRun: false, doneMeters: 8_000) == nil)
    }

    @Test func onlyTheRunMatchedByThePlanShowsThePrescription() {
        #expect(WorkoutPrescriptionBuilder.prescription(row: row(kind: .threshold), activityId: 7, isRun: true, doneMeters: 2_000) == nil)
        #expect(WorkoutPrescriptionBuilder.prescription(row: row(kind: .threshold, runId: nil), activityId: 42, isRun: true, doneMeters: 2_000) == nil)
    }
}
