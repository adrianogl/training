import Foundation
import Storage
import SwiftData
import Testing
@testable import trAIning

private actor RefreshLog {
    private(set) var events: [String] = []
    private(set) var running = 0
    private(set) var maxRunning = 0

    func start(_ index: Int) {
        running += 1
        maxRunning = max(maxRunning, running)
        events.append("start \(index)")
    }

    func end(_ index: Int) {
        running -= 1
        events.append("end \(index)")
    }
}

@MainActor
@Suite struct ScoreRefresherTests {
    private typealias F = WorkoutDetailFixtures

    @Test func refreshesRunOneAfterAnother() async throws {
        let log = RefreshLog()
        let counter = Counter()
        let refresher = ScoreRefresher {
            let index = await counter.next()
            await log.start(index)
            try? await Task.sleep(for: .milliseconds(50))
            await log.end(index)
        }

        refresher.refresh()
        await refresher.refresh().value

        #expect(await log.events == ["start 1", "end 1", "start 2", "end 2"])
        #expect(await log.maxRunning == 1)
    }

    @Test func lastRefreshLeavesKeyOfLatestData() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        for (index, daysAgo) in [0.0, 7].enumerated() {
            let record = F.run(id: Int64(index + 1), daysAgo: daysAgo, meters: 5_900, workoutName: "Tiros 3 x 1 km", structure: F.intervalStructure())
            record.thresholdUsed = 170
            context.insert(record)
        }
        try context.save()
        let refresher = ScoreRefresher { await ScoreStore.refresh(container: container, ids: nil) }

        refresher.refresh()
        let latest = try #require(try context.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == 1 })).first)
        latest.thresholdUsed = 175
        try context.save()
        await refresher.refresh().value

        let check = ModelContext(container)
        let records = try check.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        let record = try #require(records.first { $0.activityId == 1 })
        let previous = WorkoutAnalysisContext.comparisonCandidates(of: record, in: records)
        #expect(record.scoreKey == ScoreStore.key(record: record, previous: previous, watchFloors: nil))
        #expect(record.scoreKey?.contains("175") == true)
    }
}

private actor Counter {
    private var value = 0

    func next() -> Int {
        value += 1
        return value
    }
}
