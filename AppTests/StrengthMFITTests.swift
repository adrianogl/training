import Foundation
import GarminAPI
import MFIT
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct StrengthMFITTests {
    private let squat = StrengthBlock(exercises: [StrengthExercise(name: "Agachamento", detail: "10 rep", category: "SQUAT", exerciseKey: nil, reps: 10, seconds: nil)], sets: 3, restSeconds: 60)
    private let bench = StrengthBlock(exercises: [StrengthExercise(name: "Supino", detail: "10 rep", category: "BENCH_PRESS", exerciseKey: nil, reps: 10, seconds: nil, weight: 14)], sets: 4, restSeconds: 60)

    private func program() -> MFITProgram {
        MFITProgram(id: 1, title: "Treino 7", start: "2026-11-13", end: "2026-11-27", workouts: [
            MFITWorkout(id: 10, title: "Superiores", order: 0, blocks: [bench], completions: [MFITCompletion(day: "2026-11-16", start: nil, end: nil, effort: 3)]),
            MFITWorkout(id: 11, title: "MMII", order: 1, blocks: [squat], completions: [MFITCompletion(day: "2026-11-18", start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 2_700), effort: 4)]),
            MFITWorkout(id: 12, title: "Full Body", order: 2, blocks: [squat, bench], completions: []),
        ])
    }

    private func schedule() -> StrengthSchedule {
        let suite = "strength-mfit-\(UUID().uuidString)"
        return StrengthSchedule(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func placesWorkoutsOnMondayWednesdayFridayInsideProgram() {
        let schedule = schedule()
        let week = schedule.workouts(program(), from: Day(iso: "2026-11-09")!, through: Day(iso: "2026-11-15")!)
        #expect(week.map(\.day) == ["2026-11-13"])
        #expect(week.map(\.title) == ["Full Body"])

        let next = schedule.workouts(program(), from: Day(iso: "2026-11-16")!, through: Day(iso: "2026-11-22")!)
        #expect(next.map(\.day) == ["2026-11-16", "2026-11-18", "2026-11-20"])
        #expect(next.map(\.id) == [10, 11, 12])
    }

    @Test func customWeekdayMovesOrHidesWorkout() {
        let schedule = schedule()
        let workouts = program().workouts
        schedule.setWeekday(1, for: workouts[0])
        schedule.setWeekday(nil, for: workouts[2])
        let week = schedule.workouts(program(), from: Day(iso: "2026-11-16")!, through: Day(iso: "2026-11-22")!)
        #expect(week.map(\.day) == ["2026-11-17", "2026-11-18"])
        #expect(schedule.weekday(for: workouts[2]) == nil)
    }

    @Test func matchesGarminSessionsAndAddsMFITOnlyCompletions() {
        let records = [
            StrengthModel.Record(id: 500, day: Day(iso: "2026-11-16")!, name: "Força", seconds: 3_000, averageHR: 98.4, maxHR: 140),
            StrengthModel.Record(id: 501, day: Day(iso: "2026-11-20")!, name: "Full Body (sexta)", seconds: 3_600, averageHR: 101, maxHR: 150),
            StrengthModel.Record(id: 502, day: Day(iso: "2026-10-01")!, name: "Treino antigo", seconds: 2_400, averageHR: 90, maxHR: 120),
        ]
        let sessions = StrengthModel.sessions(records: records, known: program().workouts)

        #expect(sessions.map(\.day.iso) == ["2026-11-20", "2026-11-18", "2026-11-16", "2026-10-01"])
        let monday = sessions[2]
        #expect(monday.id == 500)
        #expect(monday.title == "Superiores")
        #expect(monday.workoutId == 10)
        #expect(monday.minutes == 50)
        #expect(monday.averageHR == 98)
        #expect(monday.effort == 3)

        #expect(sessions[0].workoutId == 12)
        #expect(sessions[0].effort == nil)

        let wednesday = sessions[1]
        #expect(wednesday.id < 0)
        #expect(wednesday.workoutId == 11)
        #expect(wednesday.minutes == 45)
        #expect(wednesday.averageHR == nil)

        #expect(sessions[3].workoutId == nil)
        #expect(sessions[3].title == "Treino antigo")
    }

    @Test func setsLabelShowsLoad() {
        #expect(StrengthText.setsLabel(4, detail: "10 rep", weight: 14) == "4 × 10 rep · 14 kg")
        #expect(StrengthText.setsLabel(3, detail: nil, weight: 12.5) == "3 séries · 12,5 kg")
        #expect(StrengthText.programLabel("Treino 7", start: Day(iso: "2026-11-13"), end: Day(iso: "2026-12-18")) == "Treino 7 · 13/11 a 18/12")
    }
}
