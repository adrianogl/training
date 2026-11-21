import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let today = Day(iso: "2026-11-21")!

@Suite struct MorningSyncTests {
    @Test func fetchesOnlyYesterdayAndTodayDailyData() async throws {
        let firstDay = today.adding(days: -20)
        let fake = FakeDataSource(dataDays: firstDay...today, activities: [FakeDataSource.activity(id: 1, typeKey: "running", day: today.adding(days: -1))])
        let container = try TrainingSchema.container(inMemory: true)
        _ = try await SyncEngine(source: fake, container: container, today: { today }, firstDay: firstDay).run()
        let pagesBefore = await fake.activityPageStarts.count
        let zonesBefore = await fake.zonesCalls
        let fitBefore = await fake.fitCalls.count

        let report = try await SyncEngine(source: fake, container: container, today: { today }, firstDay: firstDay, mode: .background).runMorning()

        #expect(await fake.activityPageStarts.count == pagesBefore)
        #expect(await fake.zonesCalls == zonesBefore)
        #expect(await fake.fitCalls.count == fitBefore)
        #expect(await fake.hrvFroms.last == today.adding(days: -1))
        #expect(await fake.sleepFroms.last == today.adding(days: -1))
        #expect(report.dailyUpserted == 2)
    }

    @Test func doesNothingBeforeTheFirstFullLoad() async throws {
        let fake = FakeDataSource(dataDays: today.adding(days: -5)...today)
        let container = try TrainingSchema.container(inMemory: true)
        let report = try await SyncEngine(source: fake, container: container, today: { today }, firstDay: today.adding(days: -5), mode: .background).runMorning()
        #expect(report.dailyUpserted == 0)
        #expect(await fake.hrvFroms.isEmpty)
    }
}
