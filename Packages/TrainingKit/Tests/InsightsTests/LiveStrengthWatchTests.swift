import Foundation
import Testing
@testable import Insights

@Suite struct LiveStrengthWatchTests {
    private let plan = LiveStrengthPlan(day: "2026-11-24", title: "Superiores", source: .mfit, blocks: [
        LiveStrengthBlock(id: "b1", exercises: [
            LiveStrengthExercise(
                id: "b1e1", name: "Remada curvada", category: "ROW", exerciseKey: "ROW/BARBELL_ROW", loadKey: "remada curvada", kind: .reps,
                reps: 10, seconds: nil, weight: 30, bodyweight: false, perSide: false,
                last: [LiveStrengthSetResult(reps: 10, weight: 27.5, start: Date(timeIntervalSince1970: 1_700_000_000), durationSeconds: 40)]
            ),
        ], rounds: 4, restSeconds: 90),
        LiveStrengthBlock(id: "b2", exercises: [
            LiveStrengthExercise(
                id: "b2e1", name: "Prancha", category: "PLANK", exerciseKey: nil, loadKey: "prancha", kind: .timed,
                reps: nil, seconds: 45, weight: nil, bodyweight: true, perSide: false
            ),
        ], rounds: 3, restSeconds: 0),
    ])

    @Test func messageUsesTheKeysTheWatchReads() throws {
        let data = try LiveStrengthWatch.message([plan])
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let plans = try #require(object["plans"] as? [[String: Any]])
        #expect(plans.count == 1)
        #expect(Set(plans[0].keys) == ["day", "title", "blocks", "version"])
        #expect(plans[0]["version"] as? String == LiveStrengthWatch.version(plan))
        let block = try #require((plans[0]["blocks"] as? [[String: Any]])?.first)
        #expect(Set(block.keys) == ["id", "rounds", "restSeconds", "exercises"])
        let exercise = try #require((block["exercises"] as? [[String: Any]])?.first)
        #expect(Set(exercise.keys) == ["id", "name", "kind", "reps", "weight", "bodyweight", "perSide", "last"])
        #expect(exercise["kind"] as? String == "reps")
        let last = try #require((exercise["last"] as? [[String: Any]])?.first)
        #expect(Set(last.keys) == ["reps", "weight"])
    }

    @Test func timedExerciseSendsSecondsWithoutReps() throws {
        let data = try LiveStrengthWatch.message([plan])
        let message = try JSONDecoder().decode(LiveStrengthWatchMessage.self, from: data)
        let prancha = message.plans[0].blocks[1].exercises[0]
        #expect(prancha.kind == .timed)
        #expect(prancha.seconds == 45)
        #expect(prancha.reps == nil)
        #expect(prancha.last.isEmpty)
    }

    @Test func historyKeepsTheLatestDayBeforeTheWorkout() {
        let records = [
            LiveStrengthLoadHistory(key: "remada", day: "2026-11-10", loads: [25, 25]),
            LiveStrengthLoadHistory(key: "remada", day: "2026-11-17", loads: [27.5, 27.5, 30]),
            LiveStrengthLoadHistory(key: "remada", day: "2026-11-24", loads: [32.5]),
            LiveStrengthLoadHistory(key: "supino", day: "2026-11-17", loads: []),
        ]
        let history = LiveStrengthWatch.history(records, before: "2026-11-24")
        #expect(history["remada"]?.map(\.weight) == [27.5, 27.5, 30])
        #expect(history["supino"] == nil)
    }

    @Test func versionChangesWhenThePlanChanges() {
        var heavier = plan
        heavier.blocks[0].exercises[0].weight = 32.5
        #expect(LiveStrengthWatch.version(plan) == LiveStrengthWatch.version(plan))
        #expect(LiveStrengthWatch.version(plan) != LiveStrengthWatch.version(heavier))
    }

    @Test func planFromTheWatchTakesCategoriesFromTheKnownPlan() throws {
        var changed = plan
        changed.blocks[0].exercises[0].weight = 35
        let message = try LiveStrengthWatch.message([changed])
        let object = try #require(try JSONSerialization.jsonObject(with: message) as? [String: Any])
        let watchPlan = try JSONSerialization.data(withJSONObject: try #require((object["plans"] as? [Any])?.first))
        let rebuilt = try #require(LiveStrengthWatch.plan(fromWatch: watchPlan, known: [plan], loadKey: { $0.lowercased() }))
        #expect(rebuilt.blocks[0].exercises[0].weight == 35)
        #expect(rebuilt.blocks[0].exercises[0].category == "ROW")
        #expect(rebuilt.blocks[0].exercises[0].loadKey == "remada curvada")
        #expect(rebuilt.source == .mfit)
        #expect(LiveStrengthWatch.plan(fromWatch: watchPlan, known: [], loadKey: { "k:" + $0 })?.blocks[1].exercises[0].loadKey == "k:Prancha")
    }
}

