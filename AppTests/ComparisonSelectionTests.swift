import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import trAIning

@MainActor
@Suite struct ComparisonSelectionTests {
    private typealias F = WorkoutDetailFixtures

    private static func free(id: Int64, daysAgo: Double, meters: Double = 10_000, workoutName: String? = nil) -> ActivityRecord {
        F.run(id: id, daysAgo: daysAgo, meters: meters, workoutName: workoutName, structure: F.freeStructure(kilometers: Int(meters / 1_000), hr: 165))
    }

    private static func emptyPacePro() -> PaceProStore {
        let suite = "ComparisonSelectionTests-\(UUID().uuidString)"
        return PaceProStore(url: FileManager.default.temporaryDirectory.appending(path: "\(suite).json"), defaults: UserDefaults(suiteName: suite)!)
    }

    private static func ids(_ records: [ActivityRecord]) -> [Int64] {
        records.map(\.activityId)
    }

    private static func race(on record: ActivityRecord, distance: Double = 10_000) -> RaceIndex {
        RaceIndex(pending: [WorkoutAnalysisContext.day(record): [RaceTarget(distance: distance)]])
    }

    @Test func freeRunIgnoresPlannedWorkoutsAndRaces() {
        let current = Self.free(id: 1, daysAgo: 0)
        let records = [
            current,
            Self.free(id: 2, daysAgo: 3, workoutName: "Limiar 3 x 2 km"),
            Self.free(id: 3, daysAgo: 5),
            Self.free(id: 4, daysAgo: 10),
            Self.free(id: 5, daysAgo: 120),
        ]
        let races = RaceIndex(results: [4: RaceTarget(distance: 10_000)])

        #expect(Self.ids(WorkoutAnalysisContext.comparisonCandidates(of: current, in: records, races: races)) == [3])
    }

    @Test func raceOnRaceDayComparesOnlyWithEarlierRaces() {
        let current = Self.free(id: 1, daysAgo: 0, meters: 9_830)
        let records = [
            current,
            Self.free(id: 2, daysAgo: 5),
            Self.free(id: 3, daysAgo: 7, workoutName: "Limiar 3 x 2 km"),
            Self.free(id: 4, daysAgo: 100, meters: 21_000),
            Self.free(id: 5, daysAgo: 200),
        ]
        var races = Self.race(on: current)
        races.results = [4: RaceTarget(distance: 21_097), 5: RaceTarget(distance: 10_000)]

        #expect(Self.ids(WorkoutAnalysisContext.comparisonCandidates(of: current, in: records, races: races)) == [5])
    }

    @Test func raceDayMatchNeedsRaceDistance() {
        let current = Self.free(id: 1, daysAgo: 0, meters: 3_000)
        let records = [current, Self.free(id: 2, daysAgo: 5, meters: 3_000)]

        #expect(Self.ids(WorkoutAnalysisContext.comparisonCandidates(of: current, in: records, races: Self.race(on: current))) == [2])
    }

    @Test func plannedWorkoutKeepsNameMatch() {
        let name = "Limiar 3 x 2 km"
        let current = Self.free(id: 1, daysAgo: 0, workoutName: name)
        let records = [current, Self.free(id: 2, daysAgo: 3), Self.free(id: 3, daysAgo: 200, workoutName: name)]
        var races = Self.race(on: current)
        races.results = [3: RaceTarget(distance: 10_000)]

        #expect(Self.ids(WorkoutAnalysisContext.comparisonCandidates(of: current, in: records, races: races)) == [3])
    }

    @Test func raceWithoutGoalOrEarlierRaceHasNoScore() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(Self.free(id: 1, daysAgo: 0, meters: 9_830))
        context.insert(Self.free(id: 2, daysAgo: 5))
        context.insert(Self.free(id: 3, daysAgo: 12))
        context.insert(RaceRecord(name: "10K", day: F.day(F.base), distance: 10_000))
        try context.save()

        await ScoreStore.refresh(container: container, ids: nil, paceProStore: Self.emptyPacePro())

        let stored = try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>())
        let race = try #require(stored.first { $0.activityId == 1 })
        #expect(race.scoreKey != nil)
        #expect(race.scoreValue == nil)
        #expect(stored.first { $0.activityId == 2 }?.scoreValue != nil)
    }

    @Test func todaysRaceScoresAgainstGoalWithoutFreeRuns() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        let race = Self.free(id: 1, daysAgo: 0, meters: 9_830)
        race.duration = 2_621.6
        context.insert(race)
        context.insert(Self.free(id: 2, daysAgo: 5))
        context.insert(Self.free(id: 3, daysAgo: 12))
        context.insert(RaceRecord(name: "10K", day: F.day(F.base), distance: 10_000, goalSeconds: 2_395.9))
        try context.save()

        await ScoreStore.refresh(container: container, ids: nil, paceProStore: Self.emptyPacePro())

        let stored = try #require(try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == 1 })).first)
        let score = try #require(WorkoutAnalysisStore.stored(stored)?.score)
        #expect(score.items.first { $0.part == .execution } == ScoreItem(part: .execution, points: 0, maximum: 50, reason: .slowerThanTarget))
        #expect(score.items.first { $0.part == .cost }?.reason == .noPreviousRace)
        #expect(WorkoutAnalysisStore.stored(stored)?.comparison == nil)
    }

    @Test func raceCostTextTalksAboutRaces() {
        #expect(ScoreConstants.reasonTexts[.lessEfficientThanRaces] == "menos eficiente que nas provas anteriores")
        #expect(ScoreConstants.reasonTexts[.moreEfficientThanRaces] == "mais eficiente que nas provas anteriores")
    }

    @Test func unlinkedRaceDayKeepsFreeRunComparison() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(Self.free(id: 1, daysAgo: 0, meters: 9_830))
        context.insert(Self.free(id: 2, daysAgo: 5))
        context.insert(RaceRecord(name: "10K", day: F.day(F.base), distance: 10_000, manuallyUnlinked: true))
        try context.save()

        await ScoreStore.refresh(container: container, ids: nil, paceProStore: Self.emptyPacePro())

        let stored = try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>())
        #expect(stored.first { $0.activityId == 1 }?.scoreValue != nil)
    }

    @Test func raceScoreUsesOnlyEarlierRaceResults() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(Self.free(id: 1, daysAgo: 0, meters: 9_830))
        context.insert(Self.free(id: 2, daysAgo: 5))
        context.insert(Self.free(id: 3, daysAgo: 150))
        context.insert(RaceRecord(name: "10K", day: F.day(F.base), distance: 10_000))
        context.insert(RaceRecord(name: "10K antiga", day: F.day(F.base.addingTimeInterval(-150 * 86_400)), distance: 10_000, resultActivityId: 3))
        try context.save()

        await ScoreStore.refresh(container: container, ids: nil, paceProStore: Self.emptyPacePro())

        let race = try #require(try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == 1 })).first)
        #expect(race.scoreValue != nil)
        #expect(WorkoutAnalysisStore.stored(race)?.comparison?.occurrences == [1, 3])
    }
}
