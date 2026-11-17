import Foundation
import Storage
import Testing
import TrainingCore
@testable import trAIning

@Suite struct GoalDraftParserTests {
    private let today = Day(iso: "2026-11-14")!

    @Test func timeGoalNeedsAValidClockAndAFutureDeadline() {
        var draft = GoalDraft(kind: .time, distanceKm: 10, time: "40:00")
        #expect(GoalDraftParser.values(draft, today: today) == .success(GoalValues(kind: .time, distanceKm: 10, targetSeconds: 2_400, deadline: nil, paceSecondsPerKm: nil)))
        draft.time = "40"
        #expect(GoalDraftParser.values(draft, today: today) == .failure(.time))
        draft.time = "40:00"
        draft.hasDeadline = true
        draft.deadline = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!
        #expect(GoalDraftParser.values(draft, today: today) == .failure(.deadline))
    }

    @Test func continuousLongNeedsDistanceAndPace() {
        let draft = GoalDraft(kind: .continuousLong, longDistance: "16,5", pace: "4:50")
        #expect(GoalDraftParser.values(draft, today: today) == .success(GoalValues(kind: .continuousLong, distanceKm: 16.5, targetSeconds: nil, deadline: nil, paceSecondsPerKm: 290)))
        #expect(GoalDraftParser.values(GoalDraft(kind: .continuousLong, longDistance: "0", pace: "4:50"), today: today) == .failure(.distance))
        #expect(GoalDraftParser.values(GoalDraft(kind: .continuousLong, longDistance: "16", pace: "1:00"), today: today) == .failure(.pace))
    }

    @Test func changingTheTargetClearsAchievement() {
        let goal = GoalRecord(kind: .time, distanceKm: 10, targetSeconds: 2_400, achievedAt: "2026-11-10")
        GoalDraftParser.apply(GoalValues(kind: .time, distanceKm: 10, targetSeconds: 2_400, deadline: "2027-03-15"), to: goal, now: .now)
        #expect(goal.achievedAt == "2026-11-10")
        GoalDraftParser.apply(GoalValues(kind: .time, distanceKm: 10, targetSeconds: 2_380), to: goal, now: .now)
        #expect(goal.achievedAt == nil)
    }

    @Test func paceTargetBecomesTimeForTheDistance() {
        let draft = GoalDraft(kind: .time, distanceKm: 21.0975, targetMode: .pace, targetPace: "4:15")

        #expect(GoalDraftParser.values(draft, today: today) == .success(GoalValues(kind: .time, distanceKm: 21.0975, targetSeconds: 5_380, deadline: nil, paceSecondsPerKm: nil)))
        #expect(GoalDraftParser.derived(draft) == "1:29:40")
        #expect(GoalDraftParser.values(GoalDraft(kind: .time, targetMode: .pace, targetPace: "1:00"), today: today) == .failure(.pace))
    }

    @Test func timeTargetShowsThePace() {
        #expect(GoalDraftParser.derived(GoalDraft(kind: .time, distanceKm: 10, time: "40:00")) == "4:00 /km")
        #expect(GoalDraftParser.derived(GoalDraft(kind: .time, distanceKm: 10, time: "x")) == nil)
    }
}
