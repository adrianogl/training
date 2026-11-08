import FITReader
import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let today = Day(iso: "2026-11-08")!

@Suite struct SingleFlightTests {
    @Test func reprocessWaitsForRunningSync() async throws {
        let fake = FakeDataSource(dataDays: nil, fitZip: try FITZipBuilder.structuredRun(seconds: 300), dailyDelay: .milliseconds(200))
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -2))
        let context = ModelContext(container)
        let start = ActivityTime.startOfDay(today.adding(days: -5)).addingTimeInterval(7 * 3_600)
        context.insert(ActivityRecord(activityId: 90, typeKey: "running", start: start, fitProcessed: true))
        try context.save()

        let (sync, reprocess) = try await withTimeout(.seconds(10)) {
            let sync = Task { try await engine.run() }
            while await fake.summaryFroms.isEmpty {
                try await Task.sleep(for: .milliseconds(5))
            }
            let reprocess = Task { try await engine.reprocess(limit: nil) }
            return (try await sync.value, try await reprocess.value)
        }

        #expect(sync.reprocessed == 1)
        #expect(reprocess.reprocessed == 0)
        #expect(await fake.fitCalls == [90])
        #expect(try ModelContext(container).fetch(FetchDescriptor<SyncState>()).first?.lastSync != nil)
    }
}
