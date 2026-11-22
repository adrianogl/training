import Foundation
import GarminAPI
import MFIT
import Testing
import TrainingCore
@testable import trAIning

@Suite struct MFITSendTests {
    private let today = Day(iso: "2026-11-21")!

    private func program(end: String?) -> MFITProgram {
        let squat = StrengthExercise(name: "Agachamento búlgaro", detail: "3x10", category: "LUNGE", exerciseKey: nil, reps: 10, seconds: nil, weight: 12)
        let custom = StrengthExercise(name: "Elevação do professor", detail: nil, category: nil, exerciseKey: nil, reps: 12, seconds: nil)
        let workout = MFITWorkout(id: 1, title: "Treino A", order: 0, blocks: [StrengthBlock(exercises: [squat, custom], sets: 3, restSeconds: 60)], completions: [])
        return MFITProgram(id: 9, title: "Programa", start: "2026-11-01", end: end, teacherId: nil, workouts: [workout])
    }

    @Test func endComesFromThePrescriptionOrFourWeeksAhead() {
        #expect(MFITSendBuilder.end(program(end: "2026-12-05"), today: today) == Day(iso: "2026-12-05"))
        #expect(MFITSendBuilder.end(program(end: nil), today: today) == today.adding(days: 28))
    }

    @Test func exercisesUseTheCatalogWhenTheNameIsKnown() {
        let exercises = MFITSendBuilder.exercises(program(end: nil).workouts[0].blocks) { name in
            name == "Agachamento búlgaro" ? "LUNGE/DUMBBELL_BULGARIAN_SPLIT_SQUAT" : nil
        }
        #expect(exercises.count == 2)
        #expect(exercises[0].category == "LUNGE")
        #expect(exercises[0].exerciseName == "DUMBBELL_BULGARIAN_SPLIT_SQUAT")
        #expect(exercises[0].sets == 3 && exercises[0].reps == 10 && exercises[0].restSeconds == 60 && exercises[0].weight == 12)
        #expect(exercises[1].description == "Elevação do professor")
        #expect(exercises[1].category == TrainerSendConstants.mfitFallbackCategory)
        #expect(exercises[1].exerciseName == nil)
    }

    @Test func itemsGoUntilTheEndAndSkipDaysTheClaudeReplaced() {
        let days = Set(["2026-11-23", "2026-11-30", "2026-12-07"])
        let items = MFITSendBuilder.items(
            workouts: days.sorted().map { StrengthWorkout(id: 1, day: $0, title: "Treino A", blocks: program(end: nil).workouts[0].blocks) },
            replaced: { $0.iso == "2026-11-30" }
        ) { _ in nil }
        #expect(items.map(\.day.iso) == ["2026-11-23", "2026-12-07"])
        #expect(items.allSatisfy { $0.key.hasPrefix(TrainerSendConstants.mfitKeyPrefix) && $0.kind == .strength && $0.isMFIT })
        #expect(items.first?.title == "MFIT · Treino A")
    }

    @Test func oldSettingsWithoutTheMFITFlagStillDecode() throws {
        let old = #"{"runFromTrainer":true,"auto":"both"}"#
        let settings = try JSONDecoder().decode(TrainerSendSettings.self, from: Data(old.utf8))
        #expect(settings.runFromTrainer)
        #expect(settings.sendsMFIT == false)
    }

    @Test func unknownExerciseGetsACategoryTheGarminAccepts() {
        let adductor = StrengthExercise(name: "Cadeira adutora", detail: "3x12", category: "HIP_ADDUCTION", exerciseKey: nil, reps: 12, seconds: nil)
        let extensor = StrengthExercise(name: "Cadeira extensora", detail: "3x12", category: "LEG_EXTENSION", exerciseKey: nil, reps: 12, seconds: nil)
        let exercises = MFITSendBuilder.exercises([StrengthBlock(exercises: [adductor, extensor], sets: 3, restSeconds: 60)]) { _ in nil }
        #expect(exercises.map(\.category) == ["HIP_STABILITY", "SQUAT"])
    }
}
