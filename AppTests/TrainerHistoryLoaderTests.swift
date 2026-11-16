import FITReader
import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import trAIning

@Suite struct TrainerHistoryLoaderTests {
    private typealias F = WorkoutDetailFixtures

    private static let today = Day(iso: F.day(F.base))!

    private static func container() throws -> ModelContainer {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(F.run(id: 1, daysAgo: 1, meters: 8_000))
        context.insert(F.run(id: 2, daysAgo: 3, meters: 11_800, workoutName: "Tiros 3 x 1 km", structure: F.intervalStructure()))
        context.insert(F.run(id: 3, daysAgo: 200, meters: 9_000))
        let ride = F.run(id: 4, daysAgo: 2, meters: 30_000)
        ride.typeKey = "cycling"
        context.insert(ride)
        for (id, daysAgo, name) in [(5, 2.0, "MMII (quarta)"), (6, 9.0, "MMII (quarta)"), (7, 250.0, "Full Body (sexta)")] as [(Int64, Double, String)] {
            let session = F.run(id: id, daysAgo: daysAgo, meters: 0)
            session.typeKey = "strength_training"
            session.name = name
            session.duration = 2_700
            context.insert(session)
        }
        context.insert(DailyRecord(day: today.adding(days: -1).iso, readinessScore: 64))
        context.insert(DailyRecord(day: today.adding(days: -300).iso, readinessScore: 40))
        context.insert(RaceRecord(name: "Meia", day: today.adding(days: 30).iso, distance: 21_097.5, priority: .a))
        try context.save()
        return container
    }

    @Test func loadsOnlyRecentRuns() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        #expect(history.runs.map(\.activityId) == [2, 1])
        #expect(history.runs.first?.meters == 11_800)
        #expect(history.runs.last?.day == Self.today.adding(days: -1))
    }

    @Test func classifiesIntervalRun() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        #expect(history.runs.first { $0.activityId == 2 }?.kind == .intervals)
        #expect(history.runs.first { $0.activityId == 1 }?.kind == .easy)
    }

    @Test func loadsReadinessWithinWindow() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        #expect(history.readiness == [Self.today.adding(days: -1): 64])
    }

    @Test func loadsStrengthSessionsWithinWindow() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        #expect(history.strength.map(\.activityId) == [6, 5])
        #expect(history.strength.allSatisfy { $0.name == "MMII (quarta)" && $0.seconds == 2_700 })
        #expect(history.strength.last?.day == Self.today.adding(days: -2))
        #expect(!history.runs.contains { [5, 6, 7].contains($0.activityId) })
    }

    @Test func detectsTheWeeklySessionFromLoadedStrength() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        let sessions = TrainerEngine.detectStrength(history: history, today: Self.today)
        #expect(sessions.map(\.name) == ["MMII"])
        #expect(sessions.first?.legLoad == .heavy)
    }

    private static func containerWithOldEffort() throws -> ModelContainer {
        let container = try Self.container()
        let context = ModelContext(container)
        let old = F.run(id: 20, daysAgo: 130, meters: 10_000)
        old.fastestSplit_5000 = 1_500
        context.insert(old)
        context.insert(DailyRecord(day: Self.today.adding(days: -125).iso, readinessScore: 71))
        try context.save()
        return container
    }

    @Test func seriesReachesBackToThePlanStart() throws {
        let start = Self.today.weekStart.adding(days: -16 * TrainerConstants.weekdayCount)
        let history = TrainerHistoryLoader.load(container: try Self.containerWithOldEffort(), today: Self.today, since: start)
        #expect(history.predictionSeries.keys.min() == start)
    }

    @Test func runsAndReadinessReachBackToAnOlderPlanStart() throws {
        let start = Self.today.weekStart.adding(days: -20 * TrainerConstants.weekdayCount)
        let history = TrainerHistoryLoader.load(container: try Self.containerWithOldEffort(), today: Self.today, since: start)
        #expect(history.readiness[Self.today.adding(days: -125)] == 71)
        #expect(history.runs.contains { $0.activityId == 20 })
        #expect(!history.runs.contains { $0.activityId == 3 })
    }

    @Test func seriesKeepsTheDefaultWindowWithoutAPlanStart() throws {
        let history = TrainerHistoryLoader.load(container: try Self.containerWithOldEffort(), today: Self.today)
        let oldest = Self.today.weekStart.adding(days: -TrainerConstants.scoreboardWeeks * TrainerConstants.weekdayCount)
        #expect(history.predictionSeries.keys.min() == oldest)
        #expect(history.readiness[Self.today.adding(days: -125)] == nil)
        #expect(!history.runs.contains { $0.activityId == 20 })
    }

    @Test func loadsBodySeriesFromDailyRecords() throws {
        let container = try Self.container()
        let context = ModelContext(container)
        context.insert(DailyRecord(day: Self.today.adding(days: -2).iso, restingHR: 48, hrvLastNight: 62.5, sleepSeconds: 27_000))
        context.insert(DailyRecord(day: Self.today.adding(days: -4).iso, hrvLastNight: 58))
        context.insert(DailyRecord(day: Self.today.adding(days: -200).iso, restingHR: 55, hrvLastNight: 70, sleepSeconds: 30_000))
        try context.save()
        let history = TrainerHistoryLoader.load(container: container, today: Self.today)
        #expect(history.hrv == [Self.today.adding(days: -2): 62.5, Self.today.adding(days: -4): 58])
        #expect(history.restingHeartRate == [Self.today.adding(days: -2): 48])
        #expect(history.sleepSeconds == [Self.today.adding(days: -2): 27_000])
    }

    @Test func dailyLoadSumsEveryActivityOfTheDay() throws {
        let history = TrainerHistoryLoader.load(container: try Self.container(), today: Self.today)
        #expect(history.dailyLoad == [
            Self.today.adding(days: -1): 80,
            Self.today.adding(days: -2): 160,
            Self.today.adding(days: -3): 80,
            Self.today.adding(days: -9): 80,
        ])
    }

    @Test func emptyStoreGivesEmptyHistory() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let history = TrainerHistoryLoader.load(container: container, today: Self.today)
        #expect(history.runs.isEmpty)
        #expect(history.readiness.isEmpty)
        #expect(history.strength.isEmpty)
        #expect(history.hrv.isEmpty)
        #expect(history.dailyLoad.isEmpty)
    }

    private static func vo2Structure() -> WorkoutStructure {
        let steps = [
            PrescribedStep(index: 0, intensity: .warmup, duration: .distance(meters: 1_000), target: .open),
            PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 50), target: .open),
            PrescribedStep(index: 2, intensity: .recovery, duration: .distance(meters: 100), target: .open),
            PrescribedStep(index: 3, intensity: .active, duration: .repeatSteps(fromIndex: 1, count: 4), target: .open),
            PrescribedStep(index: 4, intensity: .active, duration: .distance(meters: 1_000), target: .open),
            PrescribedStep(index: 5, intensity: .rest, duration: .open, target: .open),
            PrescribedStep(index: 6, intensity: .active, duration: .repeatSteps(fromIndex: 4, count: 5), target: .open),
            PrescribedStep(index: 7, intensity: .cooldown, duration: .distance(meters: 1_000), target: .open),
        ]
        var laps: [LapSummary] = []
        var offset = 0.0
        func lap(_ step: Int, _ intensity: StepIntensity, seconds: Double, distance: Double) {
            laps.append(LapSummary(
                stepIndex: step, intensity: intensity, startOffset: offset, timerSeconds: seconds, distance: distance,
                avgSpeed: distance / seconds, avgHeartRate: 160
            ))
            offset += seconds
        }
        for _ in 0..<3 { lap(0, .warmup, seconds: 360, distance: 1_000) }
        for _ in 0..<4 {
            lap(1, .active, seconds: 13, distance: 50)
            lap(2, .recovery, seconds: 40, distance: 100)
        }
        for seconds in [227.0, 227, 228, 232, 227] {
            lap(4, .active, seconds: seconds, distance: 1_000)
            lap(5, .rest, seconds: 30, distance: 60)
        }
        lap(7, .cooldown, seconds: 380, distance: 1_000)
        return WorkoutStructure(prescription: WorkoutPrescription(name: "VO2", steps: steps), laps: laps)
    }

    @Test func workPaceUsesOnlyTheActiveBlocks() throws {
        let structure = Self.vo2Structure()
        let pace = try #require(workPace(blocks: buildBlocks(structure, zones: nil))?.pace)
        #expect(abs(pace - 228.2) < 0.5)
    }

    @Test func workPaceIgnoresWarmupAndStoppedLaps() throws {
        let record = F.run(id: 9, daysAgo: 2, meters: 12_000, workoutName: "VO2", structure: Self.vo2Structure())
        let pace = try #require(workPace(record)?.pace)
        #expect(abs(pace - 228.2) < 0.5)
    }

    @Test func workPaceIsNilWithoutPrescription() {
        let record = F.run(id: 10, daysAgo: 2, meters: 5_000, structure: F.freeStructure(kilometers: 5))
        #expect(workPace(record) == nil)
    }

    @Test func workPaceDropsLapsSlowerThanEightMinutes() {
        let blocks = [WorkoutBlock(
            kind: .active, ordinal: 1, label: "Ativo", prescribed: nil,
            laps: [
                LapSummary(intensity: .active, startOffset: 0, timerSeconds: 600, distance: 1_000),
                LapSummary(intensity: .active, startOffset: 600, timerSeconds: 240, distance: 1_000),
            ],
            seconds: 840, distance: 2_000, avgSpeed: nil, avgHeartRate: nil, maxHeartRate: nil, dominantZone: nil, status: .noTarget
        )]
        #expect(workPace(blocks: blocks)?.pace == 240)
    }
}
