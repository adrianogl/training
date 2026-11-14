import Foundation
import GarminAPI
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let today = Day(iso: "2026-11-08")!

@Suite struct LightSyncTests {
    @Test func fetchesOnlyFirstPageAndFITOfNewRuns() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let activities = [
            FakeDataSource.activity(id: 1, typeKey: "running", day: today, hour: 8),
            FakeDataSource.activity(id: 2, typeKey: "cycling", day: today, hour: 6),
        ]
        let fake = FakeDataSource(dataDays: nil, activities: activities, fitZip: try FITZipBuilder.run(seconds: 300))
        let engine = SyncEngine(source: fake, container: container, today: { today })

        let report = try await engine.runLight()

        #expect(await fake.activityPageStarts == [0])
        #expect(await fake.fitCalls == [1])
        #expect(await fake.zonesCalls == 0)
        #expect(await fake.froms.isEmpty)
        #expect(report.activitiesUpserted == 2)
        #expect(report.processedActivityIds == [1])
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<DailyRecord>()) == 0)
    }

    @Test func rateLimitedActivitiesPageReportsStopWithoutThrowing() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let fake = FakeDataSource(dataDays: nil)
        await fake.failActivities(start: 0)
        let engine = SyncEngine(source: fake, container: container, today: { today })

        let report = try await engine.runLight()

        #expect(report.stoppedByRateLimit)
    }
}
