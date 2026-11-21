import Foundation
import GarminAPI
import MFIT
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct StrengthLegDayTests {
    private func model(legs: Bool) throws -> StrengthModel {
        let blocks = legs
            ? [StrengthBlock(exercises: [StrengthExercise(name: "Agachamento", detail: nil, category: "SQUAT", exerciseKey: nil, reps: 10, seconds: nil)], sets: 19, restSeconds: 60),
               StrengthBlock(exercises: [StrengthExercise(name: "Prancha", detail: nil, category: "PLANK", exerciseKey: nil, reps: nil, seconds: 30)], sets: 4, restSeconds: 30)]
            : [StrengthBlock(exercises: [StrengthExercise(name: "Supino", detail: nil, category: "BENCH_PRESS", exerciseKey: nil, reps: 10, seconds: nil)], sets: 20, restSeconds: 60),
               StrengthBlock(exercises: [StrengthExercise(name: "Panturrilha", detail: nil, category: "CALF_RAISE", exerciseKey: nil, reps: 15, seconds: nil)], sets: 3, restSeconds: 30)]
        let workout = MFITWorkout(id: 2, title: legs ? "MMII" : "Superiores", order: 1, blocks: blocks, completions: [])
        let url = FileManager.default.temporaryDirectory.appending(path: "leg-\(UUID()).json")
        StrengthProgramStore(url: url).save(StrengthProgramCache(program: nil, known: [workout]))
        let model = StrengthModel(store: StrengthProgramStore(url: url), schedule: StrengthSchedule(defaults: UserDefaults(suiteName: "leg-\(UUID())")!), today: { Day(iso: "2026-11-19")! })
        model.sessions = [StrengthSession(id: 5, day: Day(iso: "2026-11-18")!, title: workout.title, minutes: 51, averageHR: 100, maxHR: 140, workoutId: 2, effort: 3)]
        return model
    }

    @Test func detectsLegDayYesterday() throws {
        let leg = try #require(try model(legs: true).legDay(before: Day(iso: "2026-11-19")!))
        #expect(leg == StrengthLegDay(title: "MMII", sets: 23, legSets: 19))
        #expect(StrengthText.legFactorDetail(leg) == "MMII · 23 séries, 19 de perna · não entra na nota")
        #expect(StrengthText.legSentence(leg) == "Pernas ainda carregadas do MMII de ontem.")
        #expect(try model(legs: true).legDay(before: Day(iso: "2026-11-20")!) == nil)
        #expect(try model(legs: false).legDay(before: Day(iso: "2026-11-19")!) == nil)
    }

    @Test func adviceNamesSlowEndOfTheRangeAndFewerReps() {
        let leg = StrengthLegDay(title: "MMII", sets: 23, legSets: 19)
        #expect(StrengthText.legIntervalsAdvice(leg, slowPace: 231, reps: 5) == "Pernas do MMII de ontem: faça o aquecimento completo e segure o 1º tiro no topo da faixa (3:51/km). Se sentir peso, faça 4 tiros em vez de 5.")
        #expect(StrengthText.legIntervalsAdvice(leg, slowPace: nil, reps: nil) == "Pernas do MMII de ontem: faça o aquecimento completo e segure o 1º tiro no topo da faixa.")
    }

    @Test func staticLegDayUsesSessionsWithoutViewModel() throws {
        let legs = [StrengthBlock(exercises: [StrengthExercise(name: "Agachamento", detail: nil, category: "SQUAT", exerciseKey: nil, reps: 10, seconds: nil)], sets: 19, restSeconds: 60)]
        let workout = MFITWorkout(id: 2, title: "MMII", order: 1, blocks: legs, completions: [])
        let session = StrengthSession(id: 5, day: Day(iso: "2026-11-18")!, title: "MMII", minutes: 51, averageHR: 100, maxHR: 140, workoutId: 2, effort: 3)
        let leg = StrengthModel.legDay(sessions: [session], known: [2: workout], before: Day(iso: "2026-11-19")!)
        #expect(leg == StrengthLegDay(title: "MMII", sets: 19, legSets: 19))
        #expect(StrengthModel.legDay(sessions: [session], known: [:], before: Day(iso: "2026-11-19")!) == nil)
    }
}
