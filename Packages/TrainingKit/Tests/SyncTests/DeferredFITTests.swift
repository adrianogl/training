import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func record(id: Int64, daysAgo: Double) -> ActivityRecord {
    ActivityRecord(activityId: id, typeKey: "running", start: now.addingTimeInterval(-daysAgo * 86_400))
}

@Suite struct DeferredFITTests {
    @Test func splitSeparatesRecentFromOlderKeepingOrder() {
        let queue = [record(id: 1, daysAgo: 1), record(id: 2, daysAgo: 10), record(id: 3, daysAgo: 6), record(id: 4, daysAgo: 30)]

        let split = FITQueueSplit(queue: queue, deferringOlderThanDays: 7, now: now)

        #expect(split.immediate.map(\.activityId) == [1, 3])
        #expect(split.deferred.map(\.activityId) == [2, 4])
    }

    @Test func splitWithoutWindowKeepsEverythingImmediate() {
        let queue = [record(id: 1, daysAgo: 1), record(id: 2, daysAgo: 90)]

        let split = FITQueueSplit(queue: queue, deferringOlderThanDays: nil, now: now)

        #expect(split.immediate.map(\.activityId) == [1, 2])
        #expect(split.deferred.isEmpty)
    }

    @Test func runDownloadsOnlyRecentFITAndDeferredPassDownloadsTheRest() async throws {
        let today = Day.today()
        let fake = FakeDataSource(
            dataDays: nil,
            activities: [
                FakeDataSource.activity(id: 1, typeKey: "running", day: today),
                FakeDataSource.activity(id: 2, typeKey: "running", day: today.adding(days: -20)),
                FakeDataSource.activity(id: 3, typeKey: "running", day: today.adding(days: -3)),
            ],
            fitZip: try FITZipBuilder.run(seconds: 300)
        )
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(
            source: fake, container: container, today: { today }, firstDay: today.adding(days: -30), deferredFITOlderThanDays: 7
        )

        let report = try await engine.run()

        #expect(Set(await fake.fitCalls) == [1, 3])
        #expect(report.processedActivityIds == [1, 3])

        let deferred = try await engine.runDeferredFIT()

        #expect(Set(await fake.fitCalls) == [1, 2, 3])
        #expect(deferred.processedActivityIds == [2])
        #expect(try await engine.runDeferredFIT().processedActivityIds.isEmpty)
    }

    @Test func runWithoutWindowDownloadsEverythingAndDefersNothing() async throws {
        let today = Day.today()
        let fake = FakeDataSource(
            dataDays: nil,
            activities: [
                FakeDataSource.activity(id: 1, typeKey: "running", day: today),
                FakeDataSource.activity(id: 2, typeKey: "running", day: today.adding(days: -20)),
            ],
            fitZip: try FITZipBuilder.run(seconds: 300)
        )
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -30))

        _ = try await engine.run()

        #expect(Set(await fake.fitCalls) == [1, 2])
        #expect(try await engine.runDeferredFIT().processedActivityIds.isEmpty)
    }
}
