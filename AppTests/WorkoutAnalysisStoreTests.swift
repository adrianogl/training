import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import trAIning

@MainActor
@Suite struct WorkoutAnalysisStoreTests {
    @Test func scoreRefreshStoresTheAnalysisAndTheDetailReadsIt() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        let current = WorkoutDetailFixtures.run(id: 2, meters: 6_300, workoutName: "Tiros 3 x 1 km", structure: WorkoutDetailFixtures.intervalStructure())
        let previous = WorkoutDetailFixtures.run(id: 1, daysAgo: 7, meters: 6_300, workoutName: "Tiros 3 x 1 km", structure: WorkoutDetailFixtures.intervalStructure(tiroSeconds: 250))
        context.insert(current)
        context.insert(previous)
        try context.save()

        ScoreStore.update(in: context, ids: nil)

        let stored = try #require(WorkoutAnalysisStore.stored(current))
        let records = try context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        let fresh = WorkoutAnalysisContext.build(record: current, records: records, in: context)
        #expect(stored.blocks == fresh.blocks)
        #expect(stored.assessment == fresh.assessment)
        #expect(stored.score == fresh.score)
        #expect(stored.comparisonRows == fresh.comparisonRows)
        #expect(current.scoreValue == fresh.score?.value)
    }

    @Test func outdatedVersionIsIgnored() throws {
        let record = WorkoutDetailFixtures.run(id: 3, meters: 5_000)
        record.analysisData = WorkoutAnalysisStore.encode(WorkoutAnalysisContext())
        record.scoreKey = "1.0|-"
        #expect(WorkoutAnalysisStore.stored(record) == nil)
        record.scoreKey = ScoreStore.versionTag + WorkoutConstants.scoreKeySeparator + "-"
        #expect(WorkoutAnalysisStore.stored(record) != nil)
    }
}
