import Foundation
import Insights
import Storage
import Testing
import WorkoutAnalysis
@testable import trAIning

@Suite struct WorkoutNoticeRecordsTests {
    private static let october3 = DateComponents(calendar: .current, year: 2026, month: 10, day: 3, hour: 7).date!

    private static func run(meters: Double, seconds: Double, name: String) -> ActivityRecord {
        ActivityRecord(activityId: 1, typeKey: "running", name: name, start: .now, distance: meters, duration: seconds, movingDuration: seconds)
    }

    private static func hit(_ meters: Double, _ seconds: Double, previous: Double?, source: RecordSource = .wholeRun) -> RecordHit {
        RecordHit(effort: RunEffort(meters: meters, seconds: seconds, source: source), previousSeconds: previous, previousStart: previous == nil ? nil : october3)
    }

    private static func timeGoal(km: Double, target: Double) -> GoalSnapshot {
        GoalSnapshot(
            id: UUID(), kind: .time, distanceKm: km, targetSeconds: target, deadline: nil, paceSecondsPerKm: nil,
            progress: .time(TimeGoalProgress(todaySeconds: nil, gapSeconds: nil, crossing: .noGoal, achievedOn: nil))
        )
    }

    @Test func singleRecordGoesToTheTitleWithTheGain() {
        let content = WorkoutNotice.content(
            record: Self.run(meters: 5_000, seconds: 1_421, name: "Ritmo 5 km"), score: 92, opening: "Ritmo firme.",
            records: RunRecords(records: [Self.hit(5_000, 1_421, previous: 1_445)], near: nil)
        )

        #expect(content.title == "Recorde nos 5 km · Ritmo 5 km · nota 92")
        #expect(content.body == "23:41, 24 s abaixo do anterior (24:05, 03/10). Ritmo firme.")
    }

    @Test func segmentRecordNamesTheDistance() {
        let content = WorkoutNotice.content(
            record: Self.run(meters: 9_000, seconds: 2_700, name: "Intervalado"), score: nil, opening: nil,
            records: RunRecords(records: [Self.hit(1_000, 252, previous: 258, source: .segment)], near: nil)
        )

        #expect(content.title == "Recorde no 1 km · Intervalado")
        #expect(content.body.hasPrefix("Melhor 1 km em 4:12, 6 s abaixo do anterior (4:18, 03/10)."))
    }

    @Test func firstTimeAtTheDistance() {
        let content = WorkoutNotice.content(
            record: Self.run(meters: 21_100, seconds: 6_730, name: "Meia"), score: 90, opening: "Boa prova.",
            records: RunRecords(records: [Self.hit(21_097.5, 6_730, previous: nil)], near: nil)
        )

        #expect(content.title == "Primeira meia maratona · Meia · nota 90")
        #expect(content.body == "1:52:10 nos 21,1 km, o primeiro tempo na distância. Boa prova.")
    }

    @Test func severalRecordsAndGoalsAreCountedAndListed() {
        let content = WorkoutNotice.content(
            record: Self.run(meters: 21_100, seconds: 6_598, name: "Prova Meia de Floripa"), score: 94, opening: nil,
            goals: [Self.timeGoal(km: 21.1, target: 6_600), Self.timeGoal(km: 21.1, target: 6_900)],
            records: RunRecords(records: [Self.hit(21_097.5, 6_598, previous: 6_730), Self.hit(5_000, 1_410, previous: 1_421, source: .segment)], near: nil)
        )

        #expect(content.title == "2 recordes e 2 metas · Prova Meia de Floripa · nota 94")
        #expect(content.body.hasPrefix("Recordes: 21,1 km em 1:49:58 (−2:12) e 5 km em 23:30 (−11 s). Metas: "))
    }

    @Test func nearRecordShowsTheGap() {
        let near = RecordNear(effort: RunEffort(meters: 5_000, seconds: 1_429, source: .wholeRun), bestSeconds: 1_421)
        let content = WorkoutNotice.content(
            record: Self.run(meters: 5_000, seconds: 1_429, name: "Ritmo 5 km"), score: 86, opening: "Ritmo firme.",
            records: RunRecords(records: [], near: near)
        )

        #expect(content.title == "Ritmo 5 km · nota 86")
        #expect(content.body == "23:49 nos 5 km, a 8 s do recorde. Ritmo firme.")
    }
}
