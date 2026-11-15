import Foundation
import Metrics
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Reports

private let today = Day(iso: "2026-11-08")!

private func session(_ daysAgo: Int, pace: Double, km: Double = 6) -> TrainingSession {
    TrainingSession(day: today.adding(days: -daysAgo), work: WorkPace(seconds: pace * km, meters: km * 1_000))
}

@Suite struct TrainingEffortTests {
    @Test func thresholdUsesMedianOfLastFourDatedAtTheLatest() throws {
        let sessions = [session(2, pace: 248), session(9, pace: 245), session(16, pace: 250), session(23, pace: 240), session(30, pace: 200)]
        let effort = try #require(trainingEffort(TrainingEffortConstants.threshold, sessions: sessions, today: today))
        #expect(effort == Effort(distance: 10_000, seconds: (246.5 - 7) * 10, day: today.adding(days: -2), kind: .threshold))
    }

    @Test func intervalAddsFourSecondsAtFiveKilometers() throws {
        let sessions = [session(3, pace: 233, km: 3), session(10, pace: 228, km: 4)]
        let effort = try #require(trainingEffort(TrainingEffortConstants.interval, sessions: sessions, today: today))
        #expect(effort == Effort(distance: 5_000, seconds: (230.5 + 4) * 5, day: today.adding(days: -3), kind: .interval))
    }

    @Test func thresholdNeedsFiveKilometersOfActiveBlocks() {
        #expect(trainingEffort(TrainingEffortConstants.threshold, sessions: [session(2, pace: 248, km: 4.9)], today: today) == nil)
        #expect(trainingEffort(TrainingEffortConstants.interval, sessions: [session(2, pace: 230, km: 2.9)], today: today) == nil)
    }

    @Test func sessionsOlderThanNinetyDaysAreIgnored() throws {
        let sessions = [session(91, pace: 200), session(60, pace: 250)]
        let effort = try #require(trainingEffort(TrainingEffortConstants.threshold, sessions: sessions, today: today))
        #expect(effort.seconds == 2_430 && effort.day == today.adding(days: -60))
        #expect(trainingEffort(TrainingEffortConstants.threshold, sessions: [session(91, pace: 200)], today: today) == nil)
    }

    @Test func referencePredictionsFollowTheThresholdAndIntervalEfforts() throws {
        let threshold = try #require(trainingEffort(TrainingEffortConstants.threshold, sessions: [session(2, pace: 248), session(9, pace: 245), session(16, pace: 250), session(23, pace: 240)], today: today))
        let interval = try #require(trainingEffort(TrainingEffortConstants.interval, sessions: [session(3, pace: 233, km: 3), session(10, pace: 228, km: 4)], today: today))
        let tenK = try #require(predict(distance: 10_000, efforts: [threshold, interval], on: today))
        let fiveK = try #require(predict(distance: 5_000, efforts: [threshold, interval], on: today))
        let half = try #require(predict(distance: 21_097.5, efforts: [threshold, interval], on: today))
        #expect(abs(tenK - 2_395) < 5)
        #expect(abs(fiveK - 1_155) < 5)
        #expect(abs(half - 5_285) < 5)
    }

    @Test func thresholdWorkPaceIsTheMedianOfTheLastFourSessionsUpToTheDay() throws {
        let sessions = [session(2, pace: 248), session(9, pace: 245), session(16, pace: 250), session(23, pace: 240), session(30, pace: 200)]
        #expect(thresholdWorkPace(sessions, on: today) == 246.5)
        #expect(thresholdWorkPace(sessions, on: today.adding(days: -20)) == 220)
        #expect(thresholdWorkPace(sessions, on: today.adding(days: -40)) == nil)
    }

    @Test func thresholdRaceSecondsTakesTheTenKilometerEffortToTheRaceDistance() {
        #expect(thresholdRaceSeconds(workPace: 246, raceDistance: 10_000) == 2_390)
        #expect(abs(thresholdRaceSeconds(workPace: 246, raceDistance: 21_097.5) - 2_390 * pow(2.10975, 1.06)) < 1e-6)
    }
}
