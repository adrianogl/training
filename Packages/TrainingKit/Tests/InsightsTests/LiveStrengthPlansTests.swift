import Foundation
import GarminAPI
import Testing
@testable import Insights

private let superiores = StrengthWorkout(id: 1, day: "2026-11-25", title: "Superiores", blocks: [
    StrengthBlock(exercises: [
        StrengthExercise(name: "Supino reto com halteres", detail: nil, category: "BENCH_PRESS", exerciseKey: nil, reps: 10, seconds: nil, weight: 22.5),
        StrengthExercise(name: "Remada curvada", detail: nil, category: "ROW", exerciseKey: nil, reps: 10, seconds: nil, weight: 30),
    ], sets: 4, restSeconds: 90),
    StrengthBlock(exercises: [
        StrengthExercise(name: "Remada unilateral", detail: "3 x 10 cada lado", category: "ROW", exerciseKey: nil, reps: 10, seconds: nil, weight: 14),
    ], sets: 3, restSeconds: 60),
    StrengthBlock(exercises: [
        StrengthExercise(name: "Flexão de braço", detail: "3 x 12", category: "PUSH_UP", exerciseKey: nil, reps: 12, seconds: nil, weight: nil),
    ], sets: 3, restSeconds: 60),
    StrengthBlock(exercises: [
        StrengthExercise(name: "Prancha", detail: "3 x 45s", category: "PLANK", exerciseKey: nil, reps: nil, seconds: 45, weight: nil),
    ], sets: 3, restSeconds: nil),
])

private let reader = LiveStrengthMFITReader(
    loadKey: { $0.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression).lowercased().trimmingCharacters(in: .whitespaces) },
    target: { text in
        let reps = text.range(of: #"\d+(?=\s*rep)"#, options: .regularExpression).flatMap { Int(text[$0]) }
        let seconds = text.range(of: #"\d+(?=\s*seg)"#, options: .regularExpression).flatMap { Int(text[$0]) }
        return (reps, seconds)
    }
)

@Suite struct LiveStrengthPlansTests {
    @Test func mfitBiSetBecomesOneBlockWithTwoExercises() {
        let plan = LiveStrengthPlans.from(mfit: superiores, reader: reader)
        let biSet = plan.blocks[0]

        #expect(plan.source == .mfit)
        #expect(plan.totalSets == 4 * 2 + 3 + 3 + 3)
        #expect(biSet.isSuperset)
        #expect(biSet.rounds == 4)
        #expect(biSet.restSeconds == 90)
        #expect(biSet.exercises.map(\.id) == ["b1e1", "b1e2"])
        #expect(biSet.exercises.map(\.weight) == [22.5, 30])
    }

    @Test func mfitSetKinds() {
        let plan = LiveStrengthPlans.from(mfit: superiores, reader: reader)
        let unilateral = plan.blocks[1].exercises[0]
        let pushUp = plan.blocks[2].exercises[0]
        let plank = plan.blocks[3].exercises[0]

        #expect(unilateral.perSide)
        #expect(!unilateral.bodyweight)
        #expect(pushUp.bodyweight && pushUp.kind == .reps && pushUp.reps == 12)
        #expect(plank.kind == .timed && plank.seconds == 45 && plank.reps == nil)
        #expect(plan.blocks[3].restSeconds == 0)
    }

    @Test func mfitLastTimeUsesTheReaderKey() {
        let history = ["supino reto com halteres": [LiveStrengthSetResult(reps: 10, weight: 20)]]
        let plan = LiveStrengthPlans.from(mfit: superiores, reader: reader, history: history)

        #expect(plan.blocks[0].exercises[0].loadKey == "supino reto com halteres")
        #expect(plan.blocks[0].exercises[0].last == [LiveStrengthSetResult(reps: 10, weight: 20)])
        #expect(plan.blocks[0].exercises[1].last.isEmpty)
    }

    @Test func mfitCombinedBlockTakesTargetAndSideFromTheBlockNote() {
        let combined = StrengthWorkout(id: 2, day: "2026-11-25", title: "Inferiores", blocks: [
            StrengthBlock(exercises: [
                StrengthExercise(name: "Afundo (halteres)", detail: nil, category: "LUNGE", exerciseKey: nil, reps: nil, seconds: nil),
                StrengthExercise(name: "Prancha lateral", detail: nil, category: "PLANK", exerciseKey: nil, reps: nil, seconds: nil),
            ], sets: 3, restSeconds: 60, note: "3 séries de 12 repetições cada perna"),
        ])
        let history = ["afundo": [LiveStrengthSetResult(reps: 12, weight: 10)]]

        let exercises = LiveStrengthPlans.from(mfit: combined, reader: reader, history: history).blocks[0].exercises

        #expect(exercises.map(\.reps) == [12, 12])
        #expect(exercises.allSatisfy { $0.perSide })
        #expect(exercises[0].loadKey == "afundo")
        #expect(!exercises[0].bodyweight)
        #expect(exercises[0].weight == 10)
        #expect(exercises[1].bodyweight)
        #expect(exercises[1].weight == nil)
    }

    @Test func trainerExercisesBecomeSingleBlocksKeyedByCatalogId() {
        let workout = GeneratedStrengthWorkout(weekday: 3, group: .upper, intensity: .moderate, minutes: 45, place: .gym, exercises: [
            GeneratedExercise(exerciseId: "PUSH_UP/PUSH_UP", name: "Flexão de braços", category: "PUSH_UP", exerciseName: "PUSH_UP", sets: 3, reps: 12, seconds: nil, restSeconds: 60, weight: nil, perSide: false),
            GeneratedExercise(exerciseId: "PLANK/PLANK", name: "Prancha", category: "PLANK", exerciseName: "PLANK", sets: 3, reps: nil, seconds: 40, restSeconds: 45, weight: nil, perSide: false),
            GeneratedExercise(exerciseId: "BENCH_PRESS/DUMBBELL_BENCH_PRESS", name: "Supino com halteres", category: "BENCH_PRESS", exerciseName: "DUMBBELL_BENCH_PRESS", sets: 3, reps: 10, seconds: nil, restSeconds: 90, weight: nil, perSide: false),
            GeneratedExercise(exerciseId: "ROW/DUMBBELL_ROW", name: "Remada unilateral", category: "ROW", exerciseName: "DUMBBELL_ROW", sets: 3, reps: 10, seconds: nil, restSeconds: 60, weight: nil, perSide: true,
                              suggestedLoad: SuggestedLoad(weight: 14, baseId: "ROW/BARBELL_ROW", baseWeight: 30, baseDay: nil)),
        ], adjustments: [])

        let plan = LiveStrengthPlans.from(trainer: workout, day: "2026-11-25", title: "Superiores")

        #expect(plan.source == .trainer)
        #expect(plan.blocks.map(\.rounds) == [3, 3, 3, 3])
        #expect(plan.blocks.allSatisfy { !$0.isSuperset })
        #expect(plan.blocks[0].exercises[0].loadKey == "PUSH_UP/PUSH_UP")
        #expect(plan.blocks[0].exercises[0].bodyweight)
        #expect(plan.blocks[1].exercises[0].kind == .timed)
        #expect(plan.blocks[1].restSeconds == 45)
        #expect(!plan.blocks[2].exercises[0].bodyweight)
        #expect(plan.blocks[2].exercises[0].weight == nil)
        #expect(plan.blocks[3].exercises[0].perSide)
        #expect(plan.blocks[3].exercises[0].weight == 14)
        #expect(!plan.blocks[3].exercises[0].bodyweight)
    }

    @Test func suggestedLoadReplacesALowerTeacherLoadInMFIT() {
        let plan = LiveStrengthPlans.from(mfit: superiores, reader: reader, suggested: ["remada curvada": 32.5, "supino reto com halteres": 20])
        let byName = Dictionary(uniqueKeysWithValues: plan.blocks.flatMap(\.exercises).map { ($0.name, $0.weight) })
        #expect(byName["Remada curvada"] == 32.5)
        #expect(byName["Supino reto com halteres"] == 22.5)
    }
}

