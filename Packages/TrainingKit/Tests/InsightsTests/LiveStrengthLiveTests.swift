import Foundation
import Testing
@testable import Insights

@Suite struct LiveStrengthLiveTests {
    private let plan = LiveStrengthPlan(day: "2026-11-23", title: "Superiores", source: .mfit, blocks: [
        LiveStrengthBlock(id: "b1", exercises: [
            LiveStrengthExercise(
                id: "b1e1", name: "Supino reto com halteres", category: "BENCH_PRESS", exerciseKey: nil, loadKey: "supino", kind: .reps,
                reps: 10, seconds: nil, weight: 25, bodyweight: false, perSide: false, last: [LiveStrengthSetResult(reps: 10, weight: 20)]
            ),
        ], rounds: 4, restSeconds: 90),
        LiveStrengthBlock(id: "b2", exercises: [
            LiveStrengthExercise(
                id: "b2e1", name: "Prancha", category: "PLANK", exerciseKey: nil, loadKey: "prancha", kind: .timed,
                reps: nil, seconds: 45, weight: nil, bodyweight: true, perSide: false
            ),
        ], rounds: 2, restSeconds: 30),
    ])

    private func done(_ count: Int, weight: Double = 25) -> LiveStrengthSession {
        let events = (0..<count).map { index in
            LiveStrengthEvent(id: "s-\(index + 1)", sequence: index + 1, action: .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(reps: 10, weight: weight)))
        }
        return LiveStrengthQueue.replay(plan: plan, events: events)
    }

    @Test func doingShowsTheNextSetWithTargetAndLastTime() {
        let card = LiveStrengthLive.card(session: done(2), status: LiveStrengthWatchStatus(phase: .set, heartRate: 128))
        #expect(card.moment == .doing)
        #expect(card.setsDone == 2)
        #expect(card.setsTotal == 6)
        #expect(card.heartRate == 128)
        #expect(card.exerciseName == "Supino reto com halteres")
        #expect(card.shortName == "Supino reto")
        #expect(card.setNumber == 3)
        #expect(card.setCount == 4)
        #expect(card.exerciseSetsDone == 2)
        #expect(card.target == "10 × 25")
        #expect(card.last == "10 × 20")
    }

    @Test func restingShowsTheSetJustDoneAndTheRestLength() {
        let ends = Date(timeIntervalSince1970: 1_700_000_090)
        let card = LiveStrengthLive.card(session: done(3, weight: 22.5), status: LiveStrengthWatchStatus(phase: .rest, restEndsAt: ends))
        #expect(card.moment == .resting)
        #expect(card.lastDone == "10 × 22,5")
        #expect(card.target == "10 × 22,5")
        #expect(card.restEndsAt == ends)
        #expect(card.restSeconds == 90)
    }

    @Test func restOverAndPauseComeFromTheWatch() {
        #expect(LiveStrengthLive.card(session: done(1), status: LiveStrengthWatchStatus(phase: .restOver)).moment == .restOver)
        #expect(LiveStrengthLive.card(session: done(1), status: LiveStrengthWatchStatus(phase: .paused)).moment == .paused)
        #expect(LiveStrengthLive.card(session: done(1), status: nil).moment == .doing)
    }

    @Test func timedAndBodyweightTargets() {
        let card = LiveStrengthLive.card(session: done(4), status: nil)
        #expect(card.exerciseName == "Prancha")
        #expect(card.target == "45 s")
        #expect(card.last == nil)
    }

    @Test func allSetsDoneFinishes() {
        var events = (0..<4).map { index in
            LiveStrengthEvent(id: "s-\(index + 1)", sequence: index + 1, action: .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(reps: 10, weight: 25)))
        }
        events += (0..<2).map { index in
            LiveStrengthEvent(id: "p-\(index + 1)", sequence: index + 5, action: .setDone(exerciseId: "b2e1", result: LiveStrengthSetResult(seconds: 45)))
        }
        let card = LiveStrengthLive.card(session: LiveStrengthQueue.replay(plan: plan, events: events), status: LiveStrengthWatchStatus(phase: .rest))
        #expect(card.moment == .finished)
        #expect(card.setsDone == 6)
        #expect(card.lastDone == "45 s")
    }

    @Test func shortNameDropsATrailingConnector() {
        #expect(LiveStrengthLive.shortName("Flexão de braços no solo") == "Flexão")
        #expect(LiveStrengthLive.shortName("Remada curvada") == "Remada curvada")
    }
}

@Suite struct LiveStrengthScreenTests {
    private let plan = LiveStrengthPlan(day: "2026-11-23", title: "Superiores", source: .mfit, blocks: [
        LiveStrengthBlock(id: "b1", exercises: [
            LiveStrengthExercise(id: "b1e1", name: "Remada", category: nil, exerciseKey: nil, loadKey: "remada", kind: .reps, reps: 10, seconds: nil, weight: 30, bodyweight: false, perSide: false),
        ], rounds: 2, restSeconds: 60),
        LiveStrengthBlock(id: "b2", exercises: [
            LiveStrengthExercise(
                id: "b2e1", name: "Supino", category: nil, exerciseKey: nil, loadKey: "supino", kind: .reps, reps: 10, seconds: nil, weight: 22.5,
                bodyweight: false, perSide: false, last: [LiveStrengthSetResult(reps: 10, weight: 20)]
            ),
        ], rounds: 4, restSeconds: 90),
        LiveStrengthBlock(id: "b3", exercises: [
            LiveStrengthExercise(id: "b3e1", name: "Puxada", category: nil, exerciseKey: nil, loadKey: "puxada", kind: .reps, reps: 12, seconds: nil, weight: 45, bodyweight: false, perSide: false),
        ], rounds: 3, restSeconds: 60),
    ])

    private func event(_ sequence: Int, _ action: LiveStrengthAction) -> LiveStrengthEvent {
        LiveStrengthEvent(id: "e-\(sequence)", sequence: sequence, action: action)
    }

    @Test func nowListsDoneNextAndPendingSets() throws {
        let session = LiveStrengthQueue.replay(plan: plan, events: [
            event(1, .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(reps: 10, weight: 30))),
            event(2, .setDone(exerciseId: "b1e1", result: LiveStrengthSetResult(reps: 10, weight: 30))),
            event(3, .setDone(exerciseId: "b2e1", result: LiveStrengthSetResult(reps: 10, weight: 22.5))),
            event(4, .setDone(exerciseId: "b2e1", result: LiveStrengthSetResult(reps: 8, weight: 25))),
        ])
        let screen = LiveStrengthLive.screen(session: session)
        let now = try #require(screen.now)
        #expect(now.number == 2)
        #expect(now.marker == "2")
        #expect(now.exercise.name == "Supino")
        #expect(now.rows.map(\.state) == [.done, .done, .next, .pending])
        #expect(now.rows[0].doneText == "10 × 22,5")
        #expect(!now.rows[0].repsBelow && !now.rows[0].weightChanged)
        #expect(now.rows[1].doneText == "8 × 25")
        #expect(now.rows[1].repsBelow && now.rows[1].weightChanged)
        #expect(now.rows[1].plan == "10 × 22,5")
        #expect(now.rows[2].plan == "10 × 25")
        #expect(now.rows[2].last == "10 × 20")
        #expect(screen.items.map(\.exercise.name) == ["Remada", "Puxada"])
        #expect(screen.items.map(\.state) == [.done, .pending])
        #expect(screen.items[0].setsDone == 2)
    }

    @Test func skippedExerciseGoesToTheEndMarkedAsLater() {
        let session = LiveStrengthQueue.replay(plan: plan, events: [
            event(1, .skip(exerciseId: "b1e1")),
        ])
        let screen = LiveStrengthLive.screen(session: session)
        #expect(screen.now?.exercise.name == "Supino")
        #expect(screen.items.map(\.exercise.name) == ["Puxada", "Remada"])
        #expect(screen.items.last?.state == .skipped)
    }

    @Test func supersetExercisesGetALetterAndKeepCounting() {
        let biset = LiveStrengthPlan(day: "2026-11-23", title: "Superiores", source: .mfit, blocks: [
            LiveStrengthBlock(id: "b1", exercises: [
                LiveStrengthExercise(id: "b1e1", name: "Panturrilha", category: nil, exerciseKey: nil, loadKey: "p", kind: .reps, reps: 15, seconds: nil, weight: nil, bodyweight: true, perSide: false),
            ], rounds: 3, restSeconds: 30),
            LiveStrengthBlock(id: "b2", exercises: [
                LiveStrengthExercise(id: "b2e1", name: "Prancha Copenhagen", category: nil, exerciseKey: nil, loadKey: "c", kind: .reps, reps: 20, seconds: nil, weight: nil, bodyweight: true, perSide: true),
                LiveStrengthExercise(id: "b2e2", name: "Oblíquo", category: nil, exerciseKey: nil, loadKey: "o", kind: .reps, reps: 20, seconds: nil, weight: nil, bodyweight: true, perSide: true),
            ], rounds: 3, restSeconds: 45),
            LiveStrengthBlock(id: "b3", exercises: [
                LiveStrengthExercise(id: "b3e1", name: "Supino", category: nil, exerciseKey: nil, loadKey: "s", kind: .reps, reps: 10, seconds: nil, weight: 14, bodyweight: false, perSide: false),
            ], rounds: 3, restSeconds: 60),
        ])
        let screen = LiveStrengthLive.screen(session: LiveStrengthSession(plan: biset))
        #expect(screen.now?.marker == "1")
        #expect(screen.items.map(\.marker) == ["A1", "A2", "4"])
        #expect(screen.items.map(\.superset) == ["A", "A", nil])
        #expect(screen.items.map(\.number) == [2, 3, 4])
    }
}

