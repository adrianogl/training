import Foundation
import GarminAPI
import MFIT
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct StrengthRecordTests {
    private let blocks = [
        StrengthBlock(exercises: [StrengthExercise(name: "Supino Inclinado com Barra (PTP)", detail: nil, category: "BENCH_PRESS", exerciseKey: nil, reps: 10, seconds: nil)], sets: 3, restSeconds: 60),
        StrengthBlock(exercises: [StrengthExercise(name: "supino reto no smith", detail: nil, category: "BENCH_PRESS", exerciseKey: nil, reps: 10, seconds: nil)], sets: 2, restSeconds: 60),
        StrengthBlock(exercises: [StrengthExercise(name: "Prancha", detail: nil, category: "PLANK", exerciseKey: nil, reps: nil, seconds: 30)], sets: 1, restSeconds: 30),
    ]

    @Test func matchesWatchSetsToTeacherExercisesInOrder() {
        let sets = [
            StrengthSet(category: "BENCH_PRESS", exerciseKey: nil, reps: 10, weight: 14),
            StrengthSet(category: "BENCH_PRESS", exerciseKey: nil, reps: 10, weight: 16),
            StrengthSet(category: "BENCH_PRESS", exerciseKey: nil, reps: 8, weight: 16),
            StrengthSet(category: "BENCH_PRESS", exerciseKey: nil, reps: 10, weight: 18),
            StrengthSet(category: "PLANK", exerciseKey: nil, reps: nil, weight: nil),
            StrengthSet(category: "BENCH_PRESS", exerciseKey: nil, reps: 10, weight: 20),
        ]
        let records = StrengthWatchLoads.records(sets: sets, blocks: blocks, workoutId: 7, day: "2026-11-30")
        #expect(records.map(\.exercise) == ["Supino Inclinado com Barra (PTP)", "supino reto no smith"])
        #expect(records.map(\.loads) == [[14, 16, 16], [18, 20]])
        #expect(records.allSatisfy { $0.fromWatch == true && $0.workoutId == 7 })
    }

    @Test func flagsNewRecordOnlyWhenAboveEveryEarlierLoad() {
        let workout = MFITWorkout(id: 7, title: "Superiores", order: 0, blocks: blocks, completions: [])
        func record(_ day: String, _ loads: [Double], watch: Bool = false) -> MFITLoadRecord {
            MFITLoadRecord(exercise: "Supino Inclinado com Barra (PTP)", key: MFITParser.exerciseKey("Supino Inclinado com Barra (PTP)"), day: day, loads: loads, workoutId: 7, fromWatch: watch)
        }
        let rising = StrengthModel.loadSeries([record("2026-11-16", [14]), record("2026-11-23", [12, 14]), record("2026-11-30", [14, 16], watch: true)], known: [workout], current: [workout])
        #expect(rising.first?.isNewRecord == true)
        #expect(rising.first?.points.last?.fromWatch == true)
        #expect(StrengthText.recordTitle(rising[0].name) == "Recorde no supino Inclinado com Barra")
        #expect(StrengthText.recordText(rising[0], today: Day(iso: "2026-11-30")!) == "16 kg na Superiores de hoje, 2 kg acima do recorde anterior (14 kg, 16/11).")

        let tie = StrengthModel.loadSeries([record("2026-11-16", [16]), record("2026-11-23", [16])], known: [workout], current: [workout])
        #expect(tie.first?.isNewRecord == false)
        let single = StrengthModel.loadSeries([record("2026-11-16", [16])], known: [workout], current: [workout])
        #expect(single.first?.isNewRecord == false)
    }
}
