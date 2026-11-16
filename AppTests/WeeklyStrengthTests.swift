import Foundation
import GarminAPI
import MFIT
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct WeeklyStrengthTests {
    private func block(_ name: String, _ category: String, sets: Int) -> StrengthBlock {
        StrengthBlock(exercises: [StrengthExercise(name: name, detail: nil, category: category, exerciseKey: nil, reps: 10, seconds: nil)], sets: sets, restSeconds: 60)
    }

    private func model() throws -> StrengthModel {
        let upper = MFITWorkout(id: 1, title: "Superiores", order: 0, blocks: [block("Supino Inclinado com Barra (PTP)", "BENCH_PRESS", sets: 4)], completions: [])
        let legs = MFITWorkout(id: 2, title: "MMII", order: 1, blocks: [block("Agachamento", "SQUAT", sets: 5)], completions: [])
        let full = MFITWorkout(id: 3, title: "Full Body", order: 2, blocks: [block("Remada", "ROW", sets: 3)], completions: [])
        let program = MFITProgram(id: 9, title: "Treino 7", start: "2026-11-13", end: "2026-12-18", workouts: [upper, legs, full])
        let key = MFITParser.exerciseKey("Supino Inclinado com Barra (PTP)")
        let loads = [
            MFITLoadRecord(exercise: "Supino Inclinado com Barra (PTP)", key: key, day: "2026-11-16", loads: [14], workoutId: 1),
            MFITLoadRecord(exercise: "Supino Inclinado com Barra (PTP)", key: key, day: "2026-11-23", loads: [16], workoutId: 1, fromWatch: true),
        ]
        let url = FileManager.default.temporaryDirectory.appending(path: "weekly-strength-\(UUID()).json")
        StrengthProgramStore(url: url).save(StrengthProgramCache(program: program, known: [upper, legs, full], loads: loads))
        let model = StrengthModel(store: StrengthProgramStore(url: url), schedule: StrengthSchedule(defaults: UserDefaults(suiteName: "weekly-\(UUID())")!), today: { Day(iso: "2026-11-28")! })
        model.sessions = [
            StrengthSession(id: 10, day: Day(iso: "2026-11-23")!, title: "Superiores", minutes: 46, averageHR: 98, maxHR: 140, workoutId: 1, effort: 3),
            StrengthSession(id: 11, day: Day(iso: "2026-11-27")!, title: "Full Body", minutes: 50, averageHR: 100, maxHR: 145, workoutId: 3, effort: 3),
        ]
        return model
    }

    @Test func summarizesSessionsSetsRecordsAndMisses() throws {
        let summary = try #require(try model().weekSummary(start: Day(iso: "2026-11-23")!))
        #expect(summary.done == 2)
        #expect(summary.planned == 3)
        #expect(summary.sets == 7)
        #expect(summary.groups.first?.group == .chest)
        #expect(summary.records == [WeeklyStrengthRecord(name: "Supino Inclinado com Barra", top: 16, gain: 2)])
        #expect(summary.missed == ["Faltou o MMII de quarta"])
        #expect(StrengthText.reportNotification(summary) == "Força: 2 de 3 sessões, 7 séries e recorde no supino Inclinado com Barra (16 kg).")
    }
}
