import Foundation
import GarminAPI
import Testing
@testable import Insights

private let plan = LiveStrengthPlan(day: "2026-11-23", title: "Superiores", source: .mfit, blocks: [
    block("b1", rounds: 4, ["b1e1"]),
    block("b2", rounds: 4, ["b2e1"]),
    block("b3", rounds: 3, ["b3e1"]),
    block("b4", rounds: 2, ["b4e1", "b4e2"]),
])

private func block(_ id: String, rounds: Int, _ ids: [String]) -> LiveStrengthBlock {
    LiveStrengthBlock(id: id, exercises: ids.map {
        LiveStrengthExercise(id: $0, name: $0, category: nil, exerciseKey: nil, loadKey: $0, kind: .reps, reps: 10, seconds: nil, weight: 20, bodyweight: false, perSide: false)
    }, rounds: rounds, restSeconds: 90)
}

private func done(_ exerciseId: String, reps: Int = 10, weight: Double = 20) -> LiveStrengthAction {
    .setDone(exerciseId: exerciseId, result: LiveStrengthSetResult(reps: reps, weight: weight))
}

private func events(_ actions: [LiveStrengthAction]) -> [LiveStrengthEvent] {
    actions.enumerated().map { LiveStrengthEvent(id: "e\($0.offset)", sequence: $0.offset, action: $0.element) }
}

@Suite struct LiveStrengthQueueTests {
    @Test func skipWithTwoOfFourGoesToTheEndWithTheTwoMissing() {
        let session = LiveStrengthQueue.replay(plan: plan, events: events([done("b1e1"), done("b1e1"), .skip(exerciseId: "b1e1")]))

        #expect(session.order == ["b2", "b3", "b4", "b1"])
        #expect(LiveStrengthQueue.current(session)?.id == "b2")
        #expect(LiveStrengthQueue.pending(session).map(\.id) == ["b1"])

        let back = LiveStrengthQueue.replay(plan: plan, events: events([done("b1e1"), done("b1e1"), .skip(exerciseId: "b1e1"), .doNow(exerciseId: "b1e1")]))
        #expect(LiveStrengthQueue.next(back)?.setIndex == 2)
        #expect(LiveStrengthQueue.next(back)?.round == 3)
    }

    @Test func doNowTakesItFromTheQueueAndSendsTheCurrentToTheEnd() {
        let session = LiveStrengthQueue.replay(plan: plan, events: events([
            .skip(exerciseId: "b1e1"), done("b2e1"), .doNow(exerciseId: "b1e1"),
        ]))

        #expect(session.order == ["b1", "b3", "b4", "b2"])
        #expect(LiveStrengthQueue.current(session)?.id == "b1")
        #expect(LiveStrengthQueue.pending(session).map(\.id) == ["b2"])
    }

    @Test func doNowOnTheCurrentExerciseChangesNothing() {
        let session = LiveStrengthQueue.replay(plan: plan, events: events([done("b1e1"), .doNow(exerciseId: "b1e1")]))

        #expect(session.order == ["b1", "b2", "b3", "b4"])
        #expect(session.skipped.isEmpty)
    }

    @Test func doNowOnThePendingExerciseAtTheEndTakesItOutOfThePendingQueue() {
        var actions: [LiveStrengthAction] = [.skip(exerciseId: "b1e1")]
        actions += Array(repeating: done("b2e1"), count: 4) + Array(repeating: done("b3e1"), count: 3)
        actions += Array(repeating: done("b4e1"), count: 2) + Array(repeating: done("b4e2"), count: 2)
        let atTheEnd = LiveStrengthQueue.replay(plan: plan, events: events(actions))
        #expect(LiveStrengthQueue.current(atTheEnd)?.id == "b1")
        #expect(LiveStrengthQueue.pending(atTheEnd).map(\.id) == ["b1"])

        let resumed = LiveStrengthQueue.replay(plan: plan, events: events(actions + [.doNow(exerciseId: "b1e1")]))
        #expect(LiveStrengthQueue.pending(resumed).isEmpty)
        #expect(LiveStrengthQueue.current(resumed)?.id == "b1")
    }

    @Test func leaveOutKeepsWhatWasDone() {
        let session = LiveStrengthQueue.replay(plan: plan, events: events([
            done("b1e1"), .skip(exerciseId: "b1e1"), .leaveOut(exerciseId: "b1e1"),
        ]))

        #expect(session.leftOut == ["b1"])
        #expect(LiveStrengthQueue.pending(session).isEmpty)
        #expect(session.done["b1e1"]?.count == 1)
        #expect(LiveStrengthQueue.current(session)?.id == "b2")
    }

    @Test func repeatedOrLateEventsDoNotDuplicateSets() {
        let all = events([done("b1e1"), done("b1e1", reps: 8), done("b1e1")])
        let shuffled = [all[2], all[0], all[1], all[0], all[2]]

        let session = LiveStrengthQueue.replay(plan: plan, events: shuffled)
        #expect(session.done["b1e1"]?.map(\.reps) == [10, 8, 10])

        let received = LiveStrengthQueue.receive([all[1], all[2]], into: LiveStrengthQueue.replay(plan: plan, events: [all[0], all[1]]))
        #expect(received == session)
    }

    @Test func adjustingTheLoadCarriesToTheNextSets() {
        let session = LiveStrengthQueue.replay(plan: plan, events: events([
            done("b1e1"), done("b1e1"), .adjust(exerciseId: "b1e1", setIndex: 1, result: LiveStrengthSetResult(reps: 8, weight: 25)),
        ]))

        #expect(session.done["b1e1"]?[1] == LiveStrengthSetResult(reps: 8, weight: 25))
        #expect(LiveStrengthQueue.next(session)?.weight == 25)
        #expect(LiveStrengthQueue.next(session)?.reps == 10)
    }

    @Test func biSetAlternatesExercisesWithinTheRound() {
        let session = LiveStrengthQueue.replay(plan: plan, events: events([
            .doNow(exerciseId: "b4e1"), done("b4e1"),
        ]))

        #expect(LiveStrengthQueue.next(session)?.exerciseId == "b4e2")
        #expect(LiveStrengthQueue.next(session)?.round == 1)

        let round = LiveStrengthQueue.receive(events([.doNow(exerciseId: "b4e1"), done("b4e1"), done("b4e2")]).suffix(1).map {
            LiveStrengthEvent(id: "late", sequence: 9, action: $0.action)
        }, into: session)
        #expect(LiveStrengthQueue.next(round)?.exerciseId == "b4e1")
        #expect(LiveStrengthQueue.next(round)?.round == 2)
    }

    @Test func unknownExerciseIsIgnored() {
        let session = LiveStrengthQueue.replay(plan: plan, events: events([done("x"), .skip(exerciseId: "x")]))

        #expect(session.done.isEmpty)
        #expect(session.order == ["b1", "b2", "b3", "b4"])
    }
}
