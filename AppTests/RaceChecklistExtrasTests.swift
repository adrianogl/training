import Foundation
import Storage
import Testing
import TrainingCore
@testable import trAIning

@Suite struct RaceChecklistExtrasTests {
    private static let today = Day(iso: "2026-11-13")!

    @Test func targetsFollowRaceDistance() {
        #expect(RaceChecklistExtras.weeklyVolumeTarget(distance: 5_000) == 25)
        #expect(RaceChecklistExtras.weeklyVolumeTarget(distance: 10_000) == 30)
        #expect(RaceChecklistExtras.weeklyVolumeTarget(distance: 21_097.5) == 40)
        #expect(RaceChecklistExtras.weeklyVolumeTarget(distance: 42_195) == 55)
        #expect(RaceChecklistExtras.racePaceTarget(distance: 21_097.5) == 15)
        #expect(RaceChecklistExtras.tuneUpDistance(distance: 21_097.5) == 10)
        #expect(RaceChecklistExtras.tuneUpDistance(distance: 10_000) == 5)
    }

    @Test func recentAverageCountsWeeksWithoutRunsAsZero() {
        let week = Self.today.weekStart
        let weekly = [
            week: 50.0,
            week.adding(days: -7): 40,
            week.adding(days: -14): 44,
            week.adding(days: -28): 36,
        ]

        #expect(RaceChecklistExtras.recentAverage(weeklyKm: weekly, today: Self.today) == 30)
        #expect(RaceChecklistExtras.recentAverage(weeklyKm: [week: 50], today: Self.today) == nil)
    }

    @Test func racePaceKmCountsFullSplitsNearTargetPace() {
        let splits = [
            [
                RaceSplit(index: 0, distance: 1_000, pace: 330, planned: nil),
                RaceSplit(index: 1, distance: 1_000, pace: 282, planned: nil),
                RaceSplit(index: 2, distance: 1_000, pace: 284, planned: nil),
                RaceSplit(index: 3, distance: 1_000, pace: 268, planned: nil),
            ],
            [
                RaceSplit(index: 0, distance: 1_000, pace: 275, planned: nil),
                RaceSplit(index: 1, distance: 400, pace: 280, planned: nil),
            ],
        ]

        #expect(RaceChecklistExtras.racePaceKm(splits: splits, targetPace: 280) == 3)
    }

    @Test func thresholdItemPointsTheRaceDistanceTimeFromTheWorkPace() {
        let item = RaceChecklistExtras.thresholdItem(workPace: 246, raceDistance: 10_000, goalSeconds: 2_400)

        #expect(item.title == "Limiar vs meta")
        #expect(item.detail == "limiar 4:06 /km aponta 39:50 · meta 40:00")
        #expect(item.status == .ok)
    }

    @Test func thresholdItemNeedsAttentionWhenItPointsSlowerThanTheGoal() {
        let item = RaceChecklistExtras.thresholdItem(workPace: 252, raceDistance: 10_000, goalSeconds: 2_400)

        #expect(item.status == .attention)
    }

    @Test func thresholdItemIsMissingWithoutGoalOrWorkPace() {
        #expect(RaceChecklistExtras.thresholdItem(workPace: nil, raceDistance: 10_000, goalSeconds: 2_400).status == .missing)
        #expect(RaceChecklistExtras.thresholdItem(workPace: 246, raceDistance: 10_000, goalSeconds: nil).status == .missing)
    }

    @Test func tuneUpIgnoresRunsWithWorkBlocks() throws {
        let start = Self.today.adding(days: -3).chartDate
        let threshold = ActivityRecord(activityId: 1, typeKey: "running", name: "Limiar 10x1km", start: start, distance: 14_100, duration: 3_510)
        let input = RaceChecklistExtras.Input(
            today: Self.today, blockStart: Self.today.adding(days: -30), distance: 10_000, goalSeconds: 2_400, priority: .a,
            profile: nil, targetPace: 240, weeklyKm: [:], runs: [threshold]
        )
        let missing = try #require(RaceChecklistExtras.items(input).first { $0.kind == .tuneUp })
        #expect(missing.status == .missing)

        let steady = ActivityRecord(activityId: 2, typeKey: "running", name: "Corrida", start: start, distance: 5_400, duration: 1_300)
        let withSteady = RaceChecklistExtras.Input(
            today: Self.today, blockStart: Self.today.adding(days: -30), distance: 10_000, goalSeconds: 2_400, priority: .a,
            profile: nil, targetPace: 240, weeklyKm: [:], runs: [threshold, steady]
        )
        let found = try #require(RaceChecklistExtras.items(withSteady).first { $0.kind == .tuneUp })
        #expect(found.status == .ok)
    }
}
