import Foundation
import GarminAPI
import Testing
@testable import Insights

private func exercise(_ id: String, _ name: String, reps: Int, weight: Double, last: [LiveStrengthSetResult]) -> LiveStrengthExercise {
    LiveStrengthExercise(id: id, name: name, category: nil, exerciseKey: nil, loadKey: "mfit:\(name.lowercased())", kind: .reps, reps: reps, seconds: nil, weight: weight, bodyweight: false, perSide: false, last: last)
}

private func sets(_ reps: [Int], _ weights: [Double]) -> [LiveStrengthSetResult] {
    zip(reps, weights).map { LiveStrengthSetResult(reps: $0, weight: $1) }
}

private func repeated(_ count: Int, reps: Int, weight: Double) -> [LiveStrengthSetResult] {
    sets(Array(repeating: reps, count: count), Array(repeating: weight, count: count))
}

private let mockPlan = LiveStrengthPlan(day: "2026-11-23", title: "Superiores", source: .mfit, blocks: [
    LiveStrengthBlock(id: "b1", exercises: [exercise("b1e1", "Remada curvada", reps: 10, weight: 30, last: repeated(4, reps: 10, weight: 30))], rounds: 4, restSeconds: 90),
    LiveStrengthBlock(id: "b2", exercises: [exercise("b2e1", "Supino reto com halteres", reps: 10, weight: 22.5, last: repeated(4, reps: 10, weight: 20))], rounds: 4, restSeconds: 90),
    LiveStrengthBlock(id: "b3", exercises: [exercise("b3e1", "Desenvolvimento com halteres", reps: 12, weight: 14, last: repeated(3, reps: 12, weight: 14))], rounds: 3, restSeconds: 60),
    LiveStrengthBlock(id: "b4", exercises: [exercise("b4e1", "Puxada frente", reps: 12, weight: 45, last: repeated(3, reps: 12, weight: 45))], rounds: 3, restSeconds: 60),
    LiveStrengthBlock(id: "b5", exercises: [exercise("b5e1", "Rosca direta", reps: 12, weight: 12, last: repeated(3, reps: 12, weight: 12))], rounds: 3, restSeconds: 60),
    LiveStrengthBlock(id: "b6", exercises: [exercise("b6e1", "Tríceps corda", reps: 12, weight: 20, last: repeated(3, reps: 12, weight: 20))], rounds: 3, restSeconds: 60),
])

private func mockSession(leaveOutTriceps: Bool = false) -> LiveStrengthSession {
    var actions: [LiveStrengthAction] = []
    func add(_ id: String, _ results: [LiveStrengthSetResult]) {
        actions += results.map { .setDone(exerciseId: id, result: $0) }
    }
    add("b1e1", repeated(4, reps: 10, weight: 30))
    add("b2e1", sets([10, 8, 10, 10], [22.5, 25, 25, 25]))
    add("b3e1", repeated(3, reps: 12, weight: 16))
    add("b4e1", repeated(3, reps: 12, weight: 45))
    add("b5e1", sets([12, 12, 8], [12, 12, 12]))
    if leaveOutTriceps {
        actions += [.skip(exerciseId: "b6e1"), .leaveOut(exerciseId: "b6e1")]
    } else {
        add("b6e1", repeated(3, reps: 12, weight: 20))
    }
    let events = actions.enumerated().map { LiveStrengthEvent(id: "e\($0.offset)", sequence: $0.offset, action: $0.element) }
    return LiveStrengthQueue.replay(plan: mockPlan, events: events)
}

@Suite struct LiveStrengthReportTests {
    @Test func mockEndOfWorkoutNumbers() {
        let summary = LiveStrengthReport.summarize(mockSession(), durationSeconds: 52 * 60 + 10, averageHeartRate: 121)

        #expect(summary.setsDone == 20)
        #expect(summary.setsPlanned == 20)
        #expect(summary.offPlan == 2)
        #expect(summary.volume == 1_200 + 925 + 576 + 1_620 + 384 + 720)
        #expect(summary.previousVolume == Double(1_200 + 800 + 504 + 1_620 + 432 + 720))
        #expect(abs((summary.volumeChange ?? 0) - (5_425.0 / 5_276.0 - 1)) < 0.0001)
        #expect(summary.exercises.map(\.change) == [.asPlanned, .heavier(2.5), .heavier(2), .asPlanned, .fewerReps(4), .asPlanned])
        #expect(summary.skipped.isEmpty)
        #expect(summary.averageHeartRate == 121)
    }

    @Test func realLoadsFeedTheNextSuggestion() {
        let loads = LiveStrengthReport.loads(mockSession())

        #expect(loads["mfit:supino reto com halteres"] == StrengthLoadRecord(weight: 25, completedAllSets: false, day: "2026-11-23"))
        #expect(loads["mfit:desenvolvimento com halteres"] == StrengthLoadRecord(weight: 16, completedAllSets: true, day: "2026-11-23"))
        #expect(loads["mfit:rosca direta"] == StrengthLoadRecord(weight: 12, completedAllSets: false, day: "2026-11-23"))
    }

    @Test func leftOutExerciseShowsAsSkipped() {
        let summary = LiveStrengthReport.summarize(mockSession(leaveOutTriceps: true), durationSeconds: 3_000, averageHeartRate: nil)

        #expect(summary.setsDone == 17)
        #expect(summary.exercises.last?.change == .skipped)
        #expect(summary.skipped == ["Tríceps corda"])
        #expect(LiveStrengthReport.loads(mockSession(leaveOutTriceps: true))["mfit:tríceps corda"] == nil)
    }

    @Test func volumeChangeComparesOnlyExercisesWithHistoryDoneToday() {
        var plan = mockPlan
        plan.blocks[0].exercises[0].last = []
        let session = LiveStrengthQueue.replay(plan: plan, events: mockSession(leaveOutTriceps: true).events)

        let summary = LiveStrengthReport.summarize(session, durationSeconds: 3_000, averageHeartRate: nil)

        #expect(summary.previousVolume == Double(800 + 504 + 1_620 + 432))
        #expect(abs((summary.volumeChange ?? 0) - (Double(925 + 576 + 1_620 + 384) / 3_356 - 1)) < 0.0001)
    }

    @Test func exerciseLeftInThePendingQueueShowsAsSkipped() {
        var events = mockSession(leaveOutTriceps: true).events
        events.removeAll { $0.action == .leaveOut(exerciseId: "b6e1") }
        let session = LiveStrengthQueue.replay(plan: mockPlan, events: events)

        let summary = LiveStrengthReport.summarize(session, durationSeconds: 3_000, averageHeartRate: nil)

        #expect(LiveStrengthQueue.pending(session).map(\.id) == ["b6"])
        #expect(summary.exercises.last?.change == .skipped)
        #expect(summary.skipped == ["Tríceps corda"])
    }

    @Test func unilateralVolumeCountsBothSides() {
        #expect(LiveStrengthReport.volume([LiveStrengthSetResult(reps: 10, weight: 14)], perSide: true) == 280)
        #expect(LiveStrengthReport.volume([LiveStrengthSetResult(reps: 12, weight: nil)], perSide: false) == 0)
    }
}
