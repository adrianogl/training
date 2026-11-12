import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import trAIning

@MainActor
@Suite struct ScoreStoreTests {
    private typealias F = WorkoutDetailFixtures

    private static let name = "Tiros 3 x 1 km"
    private static let sentinel = -1

    private static func store() throws -> ModelContainer {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        for (index, daysAgo) in [0.0, 7, 14].enumerated() {
            let record = F.run(id: Int64(index + 1), daysAgo: daysAgo, meters: 5_900, workoutName: name, structure: F.intervalStructure(tiroSeconds: 245 + daysAgo))
            record.thresholdUsed = 170
            context.insert(record)
        }
        context.insert(ActivityRecord(activityId: 9, typeKey: "strength_training", name: "Força", start: F.base, duration: 2_400))
        try context.save()
        return container
    }

    private static func record(_ id: Int64, in container: ModelContainer) throws -> ActivityRecord {
        try #require(try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == id })).first)
    }

    private static func edit(_ container: ModelContainer, _ change: (ModelContext, ActivityRecord) -> Void) throws {
        let context = ModelContext(container)
        let latest = try #require(try context.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == 1 })).first)
        latest.scoreValue = sentinel
        change(context, latest)
        try context.save()
    }

    private static func refreshed() async throws -> ModelContainer {
        let container = try store()
        await ScoreStore.refresh(container: container, ids: nil)
        return container
    }

    @Test func storedScoreReadWithoutRecompute() async throws {
        let container = try await Self.refreshed()
        let first = try Self.record(1, in: container)
        let computed = try #require(first.scoreValue)
        #expect(first.scoreKey != nil)
        #expect(first.scoreData != nil)
        #expect(try Self.record(9, in: container).scoreKey == nil)

        try Self.edit(container) { _, _ in }
        await ScoreStore.refresh(container: container, ids: nil)

        let records = try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>())
        let rows = WorkoutListModel.rows(filter: .all, records: records)
        #expect(rows.first { $0.activityId == 1 }?.score == Self.sentinel)
        #expect(rows.first { $0.activityId == 9 }?.score == nil)
        #expect(computed != Self.sentinel)
    }

    @Test func recomputesWhenScoreVersionChanges() async throws {
        let container = try await Self.refreshed()
        let current = try Self.record(1, in: container).scoreKey

        try Self.edit(container) { context, record in
            let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
            let previous = WorkoutAnalysisContext.comparisonCandidates(of: record, in: records)
            record.scoreKey = ScoreStore.key(record: record, previous: previous, version: AnalysisConstants.scoreVersion + 1)
        }
        await ScoreStore.refresh(container: container, ids: nil)

        let record = try Self.record(1, in: container)
        #expect(record.scoreValue != Self.sentinel)
        #expect(record.scoreKey == current)
    }

    @Test func recomputesWhenThresholdOfDayChanges() async throws {
        let container = try await Self.refreshed()

        try Self.edit(container) { _, record in record.thresholdUsed = 175 }
        await ScoreStore.refresh(container: container, ids: nil)

        #expect(try Self.record(1, in: container).scoreValue != Self.sentinel)
    }

    @Test func recomputesWhenReprocessed() async throws {
        let container = try await Self.refreshed()

        try Self.edit(container) { _, record in record.processingVersion += 1 }
        await ScoreStore.refresh(container: container, ids: nil)

        #expect(try Self.record(1, in: container).scoreValue != Self.sentinel)
    }

    @Test func recomputesWhenPreviousRunsChange() async throws {
        let container = try await Self.refreshed()

        try Self.edit(container) { context, _ in
            context.insert(F.run(id: 4, daysAgo: 3, meters: 5_900, workoutName: Self.name, structure: F.intervalStructure(tiroSeconds: 250)))
        }
        await ScoreStore.refresh(container: container, ids: nil)

        #expect(try Self.record(1, in: container).scoreValue != Self.sentinel)
        #expect(try Self.record(4, in: container).scoreValue != nil)
    }

    @Test func readinessChangeDoesNotRecompute() async throws {
        let container = try await Self.refreshed()
        let day = try #require(try Self.record(1, in: container).localDay)

        try Self.edit(container) { context, _ in
            context.insert(DailyRecord(day: day, readinessScore: 20))
        }
        await ScoreStore.refresh(container: container, ids: nil)

        #expect(try Self.record(1, in: container).scoreValue == Self.sentinel)
    }
}
