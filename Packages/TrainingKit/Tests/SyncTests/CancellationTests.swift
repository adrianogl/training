import Foundation
import GarminAPI
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let today = Day(iso: "2026-11-08")!

private func lastSync(in container: ModelContainer) throws -> Date? {
    try ModelContext(container).fetch(FetchDescriptor<SyncState>()).first?.lastSync
}

@Suite struct CancellationTests {
    @Test func cancellationStopsRun() async throws {
        let fake = FakeDataSource(dataDays: nil, dailyDelay: .milliseconds(500))
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -400))

        let task = Task { try await engine.run() }
        while await fake.summaryFroms.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }
        task.cancel()
        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
        #expect(await fake.summaryFroms.count == 1)
        #expect(await fake.hrvFroms.isEmpty)
        #expect(await fake.activityPageStarts.isEmpty)
        #expect(try lastSync(in: container) == nil)
        #expect(try ModelContext(container).fetch(FetchDescriptor<SyncState>()).first?.firstLoadCompleted == false)
    }

    @Test func fitCancellationIsNotSkipped() async throws {
        let activities = [
            FakeDataSource.activity(id: 1, typeKey: "running", day: today),
            FakeDataSource.activity(id: 2, typeKey: "running", day: today.adding(days: -1)),
        ]
        let fake = FakeDataSource(dataDays: nil, activities: activities, fitZip: try FITZipBuilder.run(seconds: 300), cancelledFITs: [1])
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -2))

        await #expect(throws: CancellationError.self) {
            try await engine.run()
        }
        #expect(await fake.fitCalls == [1])
        #expect(try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>()).allSatisfy { !$0.fitProcessed })
        #expect(try lastSync(in: container) == nil)
    }

    @Test func zonesCancellationPropagates() async throws {
        let fake = FakeDataSource(dataDays: nil, cancelsZones: true)
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -2))

        await #expect(throws: CancellationError.self) {
            try await engine.run()
        }
        #expect(await fake.summaryFroms.isEmpty)
        #expect(try lastSync(in: container) == nil)
    }
}
