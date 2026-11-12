import FITReader
import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let today = Day(iso: "2026-11-08")!

private func activity(
    id: Int64, typeKey: String = "running", fitProcessed: Bool = true,
    version: Int = FITReaderConstants.processingVersion - 1, failures: Int = 0
) -> ActivityRecord {
    let start = ActivityTime.startOfDay(today.adding(days: -Int(id))).addingTimeInterval(7 * 3_600)
    return ActivityRecord(
        activityId: id, typeKey: typeKey, start: start,
        fitProcessed: fitProcessed, processingVersion: version, fitTransientFailures: failures
    )
}

@Suite struct OutdatedRunsTests {
    @Test func countsOnlyRunsTheQueueWouldReprocess() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(activity(id: 1, version: FITReaderConstants.processingVersion))
        context.insert(activity(id: 2, fitProcessed: false, version: 0))
        context.insert(activity(id: 3, typeKey: "cycling"))
        context.insert(activity(id: 4, failures: SyncConstants.maxFitTransientFailures))
        try context.save()

        #expect(try hasOutdatedRuns(in: context) == false)

        context.insert(activity(id: 5, failures: SyncConstants.maxFitTransientFailures - 1))
        try context.save()

        #expect(try hasOutdatedRuns(in: context))
    }

    @Test func syncQueueAndHelperAgree() async throws {
        let fake = FakeDataSource(dataDays: nil, activities: [], fitZip: try FITZipBuilder.run(seconds: 300))
        let container = try TrainingSchema.container(inMemory: true)
        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -10))
        let context = ModelContext(container)
        context.insert(activity(id: 31, failures: SyncConstants.maxFitTransientFailures))
        context.insert(activity(id: 32))
        try context.save()

        #expect(try hasOutdatedRuns(in: ModelContext(container)))

        _ = try await engine.run()

        #expect(await fake.fitCalls == [32])
        #expect(try hasOutdatedRuns(in: ModelContext(container)) == false)
    }
}
