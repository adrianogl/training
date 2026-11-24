import Foundation
import GarminAPI
import Testing
@testable import Insights

@Suite struct LiveStrengthUploadTests {
    private let plan = LiveStrengthPlan(day: "2026-11-23", title: "Superiores", source: .trainer, blocks: [
        LiveStrengthBlock(id: "b1", exercises: [
            LiveStrengthExercise(
                id: "b1e1", name: "Supino", category: "BENCH_PRESS", exerciseKey: "BENCH_PRESS/DUMBBELL_BENCH_PRESS", loadKey: "supino", kind: .reps,
                reps: 10, seconds: nil, weight: 22.5, bodyweight: false, perSide: false
            ),
        ], rounds: 2, restSeconds: 90),
        LiveStrengthBlock(id: "b2", exercises: [
            LiveStrengthExercise(id: "b2e1", name: "Flexão", category: "PUSH_UP", exerciseKey: nil, loadKey: "flexao", kind: .reps, reps: 12, seconds: nil, weight: nil, bodyweight: true, perSide: false),
        ], rounds: 1, restSeconds: 60),
    ])

    private func at(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + seconds) }

    @Test func activeSetsInOrderWithRestBetween() {
        let session = LiveStrengthQueue.replay(plan: plan, events: [
            LiveStrengthEvent(id: "1", sequence: 1, action: .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(reps: 10, weight: 22.5, start: at(0), durationSeconds: 40))),
            LiveStrengthEvent(id: "2", sequence: 2, action: .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(reps: 8, weight: 25, start: at(130), durationSeconds: 35))),
            LiveStrengthEvent(id: "3", sequence: 3, action: .setDone(exerciseId: "b2e1", result: LiveStrengthSetResult(reps: 12, start: at(300), durationSeconds: 30))),
        ])
        let sets = LiveStrengthUpload.sets(session)
        #expect(sets.map(\.kind) == [.active, .rest, .active, .rest, .active])
        #expect(sets[0].category == "BENCH_PRESS")
        #expect(sets[0].exerciseKey == "DUMBBELL_BENCH_PRESS")
        #expect(sets[1].start == at(40))
        #expect(sets[1].durationSeconds == 90)
        #expect(sets[2].reps == 8)
        #expect(sets[2].weightKg == 25)
        #expect(sets[4].category == "PUSH_UP")
        #expect(sets[4].exerciseKey == nil)
        #expect(sets[4].weightKg == nil)
    }

    @Test func adjustedSetKeepsItsTime() {
        let session = LiveStrengthQueue.replay(plan: plan, events: [
            LiveStrengthEvent(id: "1", sequence: 1, action: .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(reps: 10, weight: 22.5, start: at(0), durationSeconds: 40))),
            LiveStrengthEvent(id: "2", sequence: 2, action: .adjust(exerciseId: "b1e1", setIndex: 0, result: LiveStrengthSetResult(reps: 9, weight: 20))),
        ])
        let sets = LiveStrengthUpload.sets(session)
        #expect(sets.count == 1)
        #expect(sets[0].reps == 9)
        #expect(sets[0].weightKg == 20)
        #expect(sets[0].start == at(0))
    }

    @Test func setsWithoutRepsInheritTheLastAdjustedReps() {
        let failure = LiveStrengthPlan(day: "2026-11-23", title: "Superiores", source: .mfit, blocks: [
            LiveStrengthBlock(id: "b1", exercises: [
                LiveStrengthExercise(id: "b1e1", name: "Supino máquina", category: "BENCH_PRESS", exerciseKey: nil, loadKey: "supino-maquina", kind: .reps, reps: nil, seconds: nil, weight: 39, bodyweight: false, perSide: false),
            ], rounds: 4, restSeconds: 60),
        ])
        let session = LiveStrengthQueue.replay(plan: failure, events: [
            LiveStrengthEvent(id: "1", sequence: 1, action: .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(weight: 39, start: at(0), durationSeconds: 40))),
            LiveStrengthEvent(id: "2", sequence: 2, action: .adjust(exerciseId: "b1e1", setIndex: 0, result: LiveStrengthSetResult(reps: 20, weight: 39))),
            LiveStrengthEvent(id: "3", sequence: 3, action: .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(weight: 39, start: at(100), durationSeconds: 40))),
        ])

        #expect(LiveStrengthUpload.sets(session).filter { $0.kind == .active }.map(\.reps) == [20, 20])
        #expect(LiveStrengthQueue.effective(failure.blocks[0].exercises[0], in: session).reps == 20)
    }

    @Test func supersetPartnerFinishedTogetherSplitsTheRoundTime() {
        let superset = LiveStrengthPlan(day: "2026-11-23", title: "Superiores", source: .mfit, blocks: [
            LiveStrengthBlock(id: "b1", exercises: [
                LiveStrengthExercise(id: "b1e1", name: "Tríceps corda", category: "TRICEPS_EXTENSION", exerciseKey: nil, loadKey: "triceps", kind: .reps, reps: 10, seconds: nil, weight: 23, bodyweight: false, perSide: false),
                LiveStrengthExercise(id: "b1e2", name: "Flexão", category: "PUSH_UP", exerciseKey: nil, loadKey: "flexao", kind: .reps, reps: 10, seconds: nil, weight: nil, bodyweight: true, perSide: false),
            ], rounds: 1, restSeconds: 60),
        ])
        let session = LiveStrengthQueue.replay(plan: superset, events: [
            LiveStrengthEvent(id: "1", sequence: 1, action: .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(reps: 10, weight: 23, start: at(0), durationSeconds: 60))),
            LiveStrengthEvent(id: "2", sequence: 2, action: .setDone(exerciseId: "b1e2", result: LiveStrengthSetResult(reps: 10, start: at(60), durationSeconds: 4))),
        ])
        let active = LiveStrengthUpload.sets(session).filter { $0.kind == .active }

        #expect(active.map(\.durationSeconds) == [32, 32])
        #expect(active[1].start == at(32))
    }

    @Test func matchesOnlyAStrengthActivityStartedCloseToTheWatch() throws {
        let zone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        let startedAt = try #require(ISO8601DateFormatter().date(from: "2026-11-23T14:21:03Z"))
        let activities = [
            ActivityDTO(activityId: 1, typeKey: "running", startTimeLocal: "2026-11-23 11:21:00"),
            ActivityDTO(activityId: 2, typeKey: "strength_training", startTimeLocal: "2026-11-23 09:00:00"),
            ActivityDTO(activityId: 3, typeKey: "strength_training", startTimeLocal: "2026-11-23 11:21:10"),
        ]
        #expect(LiveStrengthUpload.match(activities, startedAt: startedAt, timeZone: zone)?.activityId == 3)
        #expect(LiveStrengthUpload.match(Array(activities.prefix(2)), startedAt: startedAt, timeZone: zone) == nil)
    }

    @Test func realLoadsKeepEverySetWithWeight() {
        let session = LiveStrengthQueue.replay(plan: plan, events: [
            LiveStrengthEvent(id: "1", sequence: 1, action: .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(reps: 10, weight: 22.5, start: at(0), durationSeconds: 40))),
            LiveStrengthEvent(id: "2", sequence: 2, action: .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(reps: 8, weight: 25, start: at(130), durationSeconds: 35))),
            LiveStrengthEvent(id: "3", sequence: 3, action: .setDone(exerciseId: "b2e1", result: LiveStrengthSetResult(reps: 12, start: at(300), durationSeconds: 30))),
        ])
        let loads = LiveStrengthReport.realLoads(session)
        #expect(loads == [LiveStrengthRealLoad(name: "Supino", loadKey: "supino", loads: [22.5, 25])])
    }
}
