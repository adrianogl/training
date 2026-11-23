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
