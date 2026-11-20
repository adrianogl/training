import Foundation
import Insights
import Storage
import Testing
import TrainingCore
@testable import trAIning

@MainActor @Suite struct RacesAndGoalsLayoutTests {
    private static let today = Day(iso: "2026-11-15")!

    private static func info(goal: Double?) -> RaceInfo {
        RaceInfo(
            id: UUID(), name: "LIVE!21K", day: Day(iso: "2026-11-22")!, distance: 21_097.5, goalSeconds: goal,
            priority: .a, city: nil, startTime: nil
        )
    }

    @Test func targetPrefersRaceDayProjection() {
        let target = RaceTargetBuilder.target(Self.info(goal: 5_340), todayPrediction: 5_400, raceDayPrediction: 5_343, today: Self.today)
        #expect(target.days == 7)
        #expect(target.dateText == "22/11")
        #expect(target.distanceText == "21,1 km")
        #expect(target.predictionSeconds == 5_343)
        #expect(target.gapText == "+0:03 da meta")
    }

    @Test func targetFallsBackToTodayPrediction() {
        let target = RaceTargetBuilder.target(Self.info(goal: 5_400), todayPrediction: 5_380, raceDayPrediction: nil, today: Self.today)
        #expect(target.predictionSeconds == 5_380)
        #expect(target.gapText == "\(TodayConstants.minusSign)0:20 da meta")
    }

    @Test func targetWithoutGoalHasNoGap() {
        let target = RaceTargetBuilder.target(Self.info(goal: nil), todayPrediction: 5_380, raceDayPrediction: nil, today: Self.today)
        #expect(target.goalSeconds == nil)
        #expect(target.gapText == nil)
    }

    @Test func pastTargetDaysNeverNegative() {
        let target = RaceTargetBuilder.target(Self.info(goal: nil), todayPrediction: nil, raceDayPrediction: nil, today: Day(iso: "2026-11-23")!)
        #expect(target.days == 0)
        #expect(target.predictionSeconds == nil)
    }

    @Test func goalStatusForTimeGoal() {
        let behind = GoalSnapshot(
            id: UUID(), kind: .time, distanceKm: 10, targetSeconds: 2_400, deadline: nil, paceSecondsPerKm: nil,
            progress: .time(TimeGoalProgress(todaySeconds: 2_425, gapSeconds: 25, crossing: .noGoal, achievedOn: nil))
        )
        #expect(GoalsText.status(behind) == GoalStatus(text: "faltam 0:25", good: false))
        var ahead = behind
        ahead.progress = .time(TimeGoalProgress(todaySeconds: 2_390, gapSeconds: -10, crossing: .alreadyBeaten, achievedOn: nil))
        #expect(GoalsText.status(ahead) == GoalStatus(text: GoalsConstants.ahead, good: true))
    }

    @Test func goalStatusForLongGoal() {
        let checks = (0..<3).map { LongRunCheck(activityId: Int64($0), day: Self.today, distanceKm: 21) }
        var goal = GoalSnapshot(
            id: UUID(), kind: .continuousLong, distanceKm: 21, targetSeconds: nil, deadline: nil, paceSecondsPerKm: 270,
            progress: .continuousLong(LongGoalProgress(runs: checks, metCount: 1, bestContinuousKm: 18.6, achievedOn: nil))
        )
        #expect(GoalsText.status(goal) == GoalStatus(text: "1 de 3", good: true))
        goal.progress = .continuousLong(LongGoalProgress(runs: [], metCount: 0, bestContinuousKm: nil, achievedOn: nil))
        #expect(GoalsText.status(goal) == nil)
    }

    @Test func settingsHaveThreeSectionsWithoutGoals() {
        #expect(SettingsSection.allCases.map(\.title) == ["Conta", "Conexões", "App"])
        #expect(SettingsSection.account.groups == [.account, .invites])
        #expect(SettingsSection.connections.groups == [.device, .garmin, .mfit, .strava, .watch, .claude])
        #expect(SettingsSection.app.groups == [.notice, .appearance, .data, .licenses])
        #expect(SettingsGroup(rawValue: "goals") == nil)
    }
}
