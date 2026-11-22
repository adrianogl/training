import FITReader
import Testing
import TrainingCore
@testable import WorkoutAnalysis

@Suite struct RaceScoreTests {
    private func split(seconds: Double, distance: Double = 1_000, heartRate: Int? = 168) -> WorkoutBlock {
        WorkoutBlock(
            kind: .active, ordinal: 1, label: "km", prescribed: nil, laps: [],
            seconds: seconds, distance: distance, avgSpeed: distance / seconds,
            avgHeartRate: heartRate, maxHeartRate: nil, dominantZone: nil, status: .noTarget
        )
    }

    private func item(_ score: WorkoutScore?, _ part: ScorePart) -> ScoreItem? {
        score?.items.first { $0.part == part }
    }

    private func race(seconds: Double, distance: Double = 10_000, target: Double? = 2_400, strategy: [Int: Double] = [:]) -> RaceScoreInput {
        RaceScoreInput(raceDistance: 10_000, targetSeconds: target, distance: distance, seconds: seconds, referencePaces: strategy)
    }

    private func evenSplits(_ pace: Double, count: Int = 10) -> [WorkoutBlock] {
        (0..<count).map { _ in split(seconds: pace) }
    }

    @Test func onTargetGivesFullExecution() {
        let score = scoreRace(race(seconds: 2_400), blocks: evenSplits(240), splits: evenSplits(240), previous: [])
        #expect(item(score, .execution) == ScoreItem(part: .execution, points: 50, maximum: 50, reason: nil))
    }

    @Test func fasterThanTargetCapsAtFullExecution() {
        #expect(item(scoreRace(race(seconds: 2_300), blocks: [], splits: [], previous: []), .execution)?.points == 50)
    }

    @Test func fivePercentSlowerGivesHalfExecution() throws {
        let execution = try #require(item(scoreRace(race(seconds: 2_520), blocks: [], splits: [], previous: []), .execution))
        #expect(abs(execution.points - 25) < 0.001)
        #expect(execution.reason == .slowerThanTarget)
    }

    @Test func elevenPercentSlowerGivesZeroExecution() {
        #expect(item(scoreRace(race(seconds: 2_664), blocks: [], splits: [], previous: []), .execution)?.points == 0)
    }

    @Test func comparesByPaceToTolerateGPSDistance() {
        let score = scoreRace(race(seconds: 2_352, distance: 9_800), blocks: [], splits: [], previous: [])
        #expect(item(score, .execution)?.points == 50)
    }

    @Test func todaysRaceGetsZeroExecutionWithoutRuns() {
        let input = RaceScoreInput(raceDistance: 10_000, targetSeconds: 2_395.9, distance: 9_830, seconds: 2_621.6)
        let score = scoreRace(input, blocks: [], splits: [], previous: [])
        #expect(item(score, .execution) == ScoreItem(part: .execution, points: 0, maximum: 50, reason: .slowerThanTarget))
        #expect(item(score, .cost)?.maximum == 0)
    }

    @Test func noTargetDropsExecution() {
        let previous = WorkoutOccurrence(activityId: 2, day: Day(iso: "2026-05-01")!, blocks: evenSplits(240))
        let score = scoreRace(race(seconds: 2_400, target: nil), blocks: evenSplits(240), splits: evenSplits(240), previous: [previous])
        #expect(item(score, .execution) == ScoreItem(part: .execution, points: 0, maximum: 0, reason: .noRaceTarget))
        #expect(item(score, .intent) == ScoreItem(part: .intent, points: 0, maximum: 0, reason: .noRaceTarget))
        #expect(item(score, .cost)?.maximum == 25)
        #expect(scoreRace(race(seconds: 2_400, target: nil), blocks: evenSplits(240), splits: evenSplits(240), previous: []) == nil)
    }

    @Test func intentCountsKilometersWithinFiveSecondsOfStrategy() throws {
        let strategy = Dictionary(uniqueKeysWithValues: (0..<10).map { ($0, $0 < 5 ? 245.0 : 235.0) })
        let paces: [Double] = [244, 249, 251, 245, 230, 235, 240, 241, 236, 235]
        let splits = paces.map { split(seconds: $0) } + [split(seconds: 20, distance: 80)]
        let intent = try #require(item(scoreRace(race(seconds: 2_400, strategy: strategy), blocks: [], splits: splits, previous: []), .intent))
        #expect(abs(intent.points - 25 * 0.7) < 0.001)
        #expect(intent.reason == .offStrategy)
    }

    @Test func intentWithoutStrategyUsesTargetPace() {
        let splits = evenSplits(240, count: 8) + [split(seconds: 250), split(seconds: 260)]
        #expect(item(scoreRace(race(seconds: 2_450), blocks: [], splits: splits, previous: []), .intent)?.points == 25 * 0.8)
    }

    @Test func noSplitsDropsIntent() {
        #expect(item(scoreRace(race(seconds: 2_400), blocks: [], splits: [], previous: []), .intent)?.reason == .noSplits)
    }

    @Test func costComparesWithPreviousRaces() {
        let previous = WorkoutOccurrence(activityId: 2, day: Day(iso: "2026-05-01")!, blocks: evenSplits(250))
        let score = scoreRace(race(seconds: 2_400), blocks: evenSplits(240), splits: evenSplits(240), previous: [previous])
        #expect(item(score, .cost)?.maximum == 25)
        #expect(item(score, .cost)?.reason == .moreEfficientThanRaces)
        #expect((score?.value ?? 0) > 95)
    }

    @Test func lessEfficientThanPreviousRacesHasRaceReason() {
        let previous = WorkoutOccurrence(activityId: 2, day: Day(iso: "2026-05-01")!, blocks: evenSplits(230))
        let score = scoreRace(race(seconds: 2_400), blocks: evenSplits(240), splits: evenSplits(240), previous: [previous])
        #expect(item(score, .cost)?.reason == .lessEfficientThanRaces)
    }

    @Test func noPreviousRaceDropsCostAndCapsScore() {
        let score = scoreRace(race(seconds: 2_400), blocks: evenSplits(240), splits: evenSplits(240), previous: [])
        #expect(item(score, .cost)?.reason == .noPreviousRace)
        #expect(score?.value == 95)
    }
}
