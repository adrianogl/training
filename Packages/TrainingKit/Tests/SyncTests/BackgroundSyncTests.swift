import Foundation
import GarminAPI
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let today = Day(iso: "2026-11-08")!

private func fetch<M: PersistentModel>(_ type: M.Type, in container: ModelContainer) throws -> [M] {
    try ModelContext(container).fetch(FetchDescriptor<M>())
}

private func runs(_ count: Int) -> [ActivityDTO] {
    (0..<count).map { FakeDataSource.activity(id: Int64(100 + $0), typeKey: "running", day: today.adding(days: -$0)) }
}

@Suite struct BackgroundSyncTests {
    @Test func backgroundStopsOnRateLimitWithoutThrowing() async throws {
        let firstDay = today.adding(days: -100)
        let activities = (0..<160).map {
            FakeDataSource.activity(id: Int64(1_000 + $0), typeKey: "cycling", day: today.adding(days: -($0 / 2)), hour: 20 - ($0 % 2) * 2)
        }
        let fake = FakeDataSource(dataDays: firstDay...today, activities: activities)
        let container = try TrainingSchema.container(inMemory: true)
        await fake.failActivities(start: 100)
        let background = SyncEngine(source: fake, container: container, today: { today }, firstDay: firstDay, mode: .background)

        let report = try await background.run()

        #expect(report.stoppedByRateLimit)
        let state = try #require(try fetch(SyncState.self, in: container).first)
        #expect(state.firstLoadCompleted == false)
        #expect(state.lastSync == nil)
        #expect(state.resumeActivityStart == 100)

        await fake.failActivities(start: nil)
        let foreground = SyncEngine(source: fake, container: container, today: { today }, firstDay: firstDay)
        let resumed = try await foreground.run()

        #expect(Array(await fake.activityPageStarts.dropFirst(3)) == [50, 100, 150])
        #expect(resumed.stoppedByRateLimit == false)
        #expect(try fetch(SyncState.self, in: container).first?.firstLoadCompleted == true)
    }

    @Test func backgroundStopsOnDailyRateLimitWithoutThrowing() async throws {
        let firstDay = today.adding(days: -40)
        let fake = FakeDataSource(dataDays: firstDay...today, activities: runs(2))
        let container = try TrainingSchema.container(inMemory: true)
        await fake.failSleep(from: firstDay.adding(days: 28))
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: firstDay, mode: .background)

        let report = try await engine.run()

        #expect(report.stoppedByRateLimit)
        #expect(await fake.activityPageStarts.isEmpty)
        let state = try #require(try fetch(SyncState.self, in: container).first)
        #expect(state.firstLoadCompleted == false)
        #expect(state.lastSync == nil)
        #expect(state.resumeSleepFrom == firstDay.adding(days: 28).iso)
    }

    @Test func backgroundRespectsFitLimit() async throws {
        let fake = FakeDataSource(dataDays: today.adding(days: -5)...today, activities: runs(5), fitZip: try FITZipBuilder.run(seconds: 300))
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -5), mode: .background)

        let report = try await engine.run()

        #expect(await fake.fitCalls.count == 3)
        #expect(report.fitProcessed == 3)
    }

    @Test func transientFitFailuresLeaveQueueAfterLimit() async throws {
        let fake = FakeDataSource(
            dataDays: today.adding(days: -2)...today,
            activities: runs(1),
            fitZip: try FITZipBuilder.run(seconds: 300),
            fitErrors: [100: .server(status: 503)]
        )
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -2))

        for _ in 0..<SyncConstants.maxFitTransientFailures + 2 { _ = try await engine.run() }

        #expect(await fake.fitCalls.count == SyncConstants.maxFitTransientFailures)
        #expect(try fetch(ActivityRecord.self, in: container).first?.fitTransientFailures == SyncConstants.maxFitTransientFailures)

        _ = try await engine.reprocess(limit: nil)

        #expect(await fake.fitCalls.count == SyncConstants.maxFitTransientFailures + 1)
        #expect(try fetch(ActivityRecord.self, in: container).first?.fitTransientFailures == 1)
    }
}
