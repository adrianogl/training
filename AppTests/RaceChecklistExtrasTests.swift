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
}
