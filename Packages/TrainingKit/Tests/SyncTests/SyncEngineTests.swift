import FITReader
import Foundation
import GarminAPI
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let today = Day(iso: "2026-11-08")!

private func makeEngine(_ fake: FakeDataSource, firstDay: Day? = nil) throws -> (SyncEngine, ModelContainer) {
    let container = try TrainingSchema.container(inMemory: true)
    let engine: SyncEngine
    if let firstDay {
        engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: firstDay)
    } else {
        engine = SyncEngine(source: fake, container: container, today: { today })
    }
    return (engine, container)
}

private func count<M: PersistentModel>(_ type: M.Type, in container: ModelContainer) throws -> Int {
    try ModelContext(container).fetchCount(FetchDescriptor<M>())
}

private func fetch<M: PersistentModel>(_ type: M.Type, in container: ModelContainer) throws -> [M] {
    try ModelContext(container).fetch(FetchDescriptor<M>())
}

private func spacedActivities(count: Int, perDay: Int, typeKey: String = "cycling") -> [ActivityDTO] {
    (0..<count).map { index in
        FakeDataSource.activity(
            id: Int64(1_000 + index),
            typeKey: typeKey,
            day: today.adding(days: -(index / perDay)),
            hour: 20 - (index % perDay) * 2
        )
    }
}

@Suite struct SyncEngineTests {
    @Test func firstLoadStartsAt2024() async throws {
        let fake = FakeDataSource(dataDays: nil)
        let (engine, _) = try makeEngine(fake)

        _ = try await engine.run()

        let hrvFroms = await fake.hrvFroms
        #expect(hrvFroms.first == Day(iso: "2024-01-01"))
        #expect(hrvFroms.count == windows(from: Day(iso: "2024-01-01")!, to: today, maxDays: 180).count)
        #expect(await fake.froms.min() == Day(iso: "2024-01-01"))
    }

    @Test func incrementalRefetchesLastThreeDays() async throws {
        let fake = FakeDataSource(dataDays: today.adding(days: -20)...today, activities: spacedActivities(count: 10, perDay: 1))
        let (engine, container) = try makeEngine(fake, firstDay: today.adding(days: -20))

        _ = try await engine.run()
        let firstRunCalls = await fake.froms.count
        let firstRunHRV = await fake.hrvFroms.count
        let second = try await engine.run()

        let secondRunFroms = await fake.froms.dropFirst(firstRunCalls)
        #expect(secondRunFroms.min() == today.adding(days: -3))
        #expect(await fake.hrvFroms.count - firstRunHRV == 1)
        #expect(second.dailyUpserted == 4)
        let state = try #require(try fetch(SyncState.self, in: container).first)
        #expect(state.firstLoadCompleted)
        #expect(state.lastSync != nil)
        #expect(state.lastActivityStart != nil)
    }

    @Test func runningTwiceCreatesNoDuplicates() async throws {
        let fake = FakeDataSource(dataDays: today.adding(days: -10)...today, activities: spacedActivities(count: 60, perDay: 6))
        let (engine, container) = try makeEngine(fake, firstDay: today.adding(days: -10))

        let recorder = ProgressRecorder()
        let first = try await engine.run(progress: { recorder.record($0) })
        let pagesAfterFirst = await fake.activityPageStarts
        let second = try await engine.run()

        #expect(try count(DailyRecord.self, in: container) == fake.dayCount)
        #expect(try count(ActivityRecord.self, in: container) == fake.activityCount)
        #expect(try count(SyncState.self, in: container) == 1)
        #expect(first.dailyUpserted == fake.dayCount)
        #expect(first.activitiesUpserted == 60)
        #expect(pagesAfterFirst == [0, 50])
        #expect(await fake.activityPageStarts.dropFirst(pagesAfterFirst.count) == [0])
        #expect(second.activitiesUpserted == 50)
        #expect(second.duplicatesRemoved == 0)
        let progress = recorder.values
        #expect(progress.first == 0)
        #expect(progress.last == 1)
        #expect(zip(progress, progress.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test func removesPreexistingDuplicates() async throws {
        let fake = FakeDataSource(dataDays: today.adding(days: -5)...today)
        let (engine, container) = try makeEngine(fake, firstDay: today.adding(days: -5))
        let context = ModelContext(container)
        context.insert(DailyRecord(day: "2026-10-01", restingHR: 40, updatedAt: Date(timeIntervalSince1970: 1_000)))
        context.insert(DailyRecord(day: "2026-10-01", restingHR: 45, updatedAt: Date(timeIntervalSince1970: 2_000)))
        try context.save()

        let report = try await engine.run()

        #expect(report.duplicatesRemoved == 1)
        let kept = try fetch(DailyRecord.self, in: container).filter { $0.day == "2026-10-01" }
        #expect(kept.count == 1)
        #expect(kept.first?.restingHR == 45)
        #expect(try count(DailyRecord.self, in: container) == fake.dayCount + 1)
    }

    @Test func processesFitOnlyForNewRuns() async throws {
        let activities = [
            FakeDataSource.activity(id: 1, typeKey: "running", day: today),
            FakeDataSource.activity(id: 2, typeKey: "trail_running", day: today.adding(days: -1)),
            FakeDataSource.activity(id: 3, typeKey: "cycling", day: today.adding(days: -2)),
            FakeDataSource.activity(id: 4, typeKey: "strength_training", day: today.adding(days: -3)),
            FakeDataSource.activity(id: 5, typeKey: "treadmill_running", day: today.adding(days: -4)),
        ]
        let fake = FakeDataSource(dataDays: nil, activities: activities, fitZip: try FITZipBuilder.run(seconds: 900))
        let (engine, container) = try makeEngine(fake, firstDay: today.adding(days: -5))
        let context = ModelContext(container)
        context.insert(ActivityRecord(activityId: 5, typeKey: "treadmill_running", fitProcessed: true, processingVersion: FITReaderConstants.processingVersion))
        try context.save()

        let first = try await engine.run()
        let second = try await engine.run()

        #expect(await fake.fitCalls.sorted() == [1, 2])
        #expect(first.fitProcessed == 2)
        #expect(second.fitProcessed == 0)
        let records = Dictionary(uniqueKeysWithValues: try fetch(ActivityRecord.self, in: container).map { ($0.activityId, $0) })
        let run = try #require(records[1])
        #expect(run.fitProcessed)
        #expect(abs((run.vo2max ?? 0) - 54.73) < 0.01)
        #expect(run.recoveryMinutes == 1_440)
        #expect(run.performanceCondition == 3)
        #expect(run.zoneSeconds == [60, 600, 1_500, 700, 140])
        let samples = try JSONDecoder().decode([FITSample].self, from: try #require(run.samplesData))
        #expect(samples.count == 180)
        let route = try JSONDecoder().decode([Coordinate].self, from: try #require(run.routeData))
        #expect(route.count >= 2)
        #expect(records[3]?.fitProcessed == false)
        #expect(records[4]?.fitProcessed == false)
        #expect(records[5]?.samplesData == nil)
    }

    @Test func processesFitForEveryRunTypeKey() async throws {
        let activities = [
            FakeDataSource.activity(id: 60, typeKey: "virtual_run", day: today),
            FakeDataSource.activity(id: 61, typeKey: "ultra_run", day: today.adding(days: -1)),
            FakeDataSource.activity(id: 62, typeKey: "running_drills", day: today.adding(days: -2)),
        ]
        let fake = FakeDataSource(dataDays: nil, activities: activities, fitZip: try FITZipBuilder.run(seconds: 300))
        let (engine, _) = try makeEngine(fake, firstDay: today.adding(days: -3))

        let report = try await engine.run()

        #expect(await fake.fitCalls.sorted() == [60, 61])
        #expect(report.fitProcessed == 2)
    }

    @Test func activityWithoutStartIsNotLatestStart() async throws {
        let undated = ActivityDTO(activityId: 70, typeKey: "cycling", distance: 10_000, duration: 3_000, activityTrainingLoad: 100)
        let fake = FakeDataSource(dataDays: today.adding(days: -2)...today, activities: [undated])
        let (engine, container) = try makeEngine(fake, firstDay: today.adding(days: -2))

        _ = try await engine.run()

        let state = try #require(try fetch(SyncState.self, in: container).first)
        #expect(try fetch(ActivityRecord.self, in: container).first?.start == .distantPast)
        #expect(state.lastActivityStart == nil)
    }

    @Test func fitFailureDoesNotAbortSync() async throws {
        let activities = [
            FakeDataSource.activity(id: 10, typeKey: "running", day: today),
            FakeDataSource.activity(id: 11, typeKey: "running", day: today.adding(days: -1)),
        ]
        let fake = FakeDataSource(dataDays: today.adding(days: -2)...today, activities: activities)
        let (engine, container) = try makeEngine(fake, firstDay: today.adding(days: -2))

        let report = try await engine.run()

        #expect(await fake.fitCalls.sorted() == [10, 11])
        #expect(report.fitProcessed == 0)
        #expect(report.activitiesUpserted == 2)
        let records = try fetch(ActivityRecord.self, in: container)
        #expect(records.count == 2)
        #expect(records.allSatisfy { !$0.fitProcessed && $0.samplesData == nil })
        #expect(try fetch(SyncState.self, in: container).first?.firstLoadCompleted == true)
    }

    @Test func storesReadiness() async throws {
        let span = today.adding(days: -40)...today
        let activities = (0...40).map { offset in
            FakeDataSource.activity(id: Int64(500 + offset), typeKey: "cycling", day: today.adding(days: -offset), load: 100)
        }
        let fake = FakeDataSource(dataDays: span, activities: activities)
        let (engine, container) = try makeEngine(fake, firstDay: span.lowerBound)

        _ = try await engine.run()

        let records = Dictionary(uniqueKeysWithValues: try fetch(DailyRecord.self, in: container).map { ($0.day, $0) })
        let record = try #require(records[today.iso])
        #expect(record.hrvLastNight == 60)
        #expect(record.hrvLowUpper == 40)
        #expect(record.sleepScore == 80)
        #expect(record.sleepSeconds == 27_000)
        #expect(record.bodyBatteryMorningMax == 85)
        #expect(record.restingHR == 50)
        #expect(record.readinessScore == 85)
        #expect(record.readinessPartial == false)
        #expect(records.values.allSatisfy { $0.readinessScore != nil })
    }

    @Test func invalidKeyPropagates() async throws {
        let fake = FakeDataSource(dataDays: today.adding(days: -2)...today, failure: .invalidKey)
        let (engine, container) = try makeEngine(fake, firstDay: today.adding(days: -2))

        await #expect(throws: GarminAPIError.invalidKey) {
            try await engine.run()
        }
        #expect(try fetch(SyncState.self, in: container).first?.firstLoadCompleted != true)
        #expect(try count(DailyRecord.self, in: container) == 0)
    }
}

@Suite struct SyncEngineFailureTests {
    @Test func gapRunResumesFromLastSuccessfulSync() async throws {
        let lastSyncDay = today.adding(days: -60)
        let fake = FakeDataSource(dataDays: today.adding(days: -70)...today)
        let container = try TrainingSchema.container(inMemory: true)
        let firstDay = today.adding(days: -70)
        let earlier = SyncEngine(source: fake, container: container, today: { lastSyncDay }, firstDay: firstDay)
        _ = try await earlier.run()
        let context = ModelContext(container)
        let state = try #require(try context.fetch(FetchDescriptor<SyncState>()).first)
        state.lastSync = ActivityTime.startOfDay(lastSyncDay).addingTimeInterval(12 * 3_600)
        try context.save()

        let engine = SyncEngine(source: fake, container: container, today: { today }, firstDay: firstDay)
        let gapStart = lastSyncDay.adding(days: -3)
        let sleepWindows = windows(from: gapStart, to: today, maxDays: 28).map(\.lowerBound)
        await fake.failSleep(from: sleepWindows[1])
        await #expect(throws: GarminAPIError.rateLimited(path: GarminEndpoints.sleepPath)) {
            try await engine.run()
        }
        await fake.failSleep(from: nil)
        let callsBeforeRetry = await fake.sleepFroms.count

        _ = try await engine.run()

        #expect(Array(await fake.sleepFroms.dropFirst(callsBeforeRetry)) == sleepWindows)
        let records = Dictionary(uniqueKeysWithValues: try fetch(DailyRecord.self, in: container).map { ($0.day, $0) })
        for offset in 0...gapStart.days(until: today) {
            #expect(records[gapStart.adding(days: offset).iso]?.sleepSeconds == 27_000)
        }
    }

    @Test func zonesDecodingFailureDoesNotAbortRun() async throws {
        let fake = FakeDataSource(dataDays: today.adding(days: -2)...today, zonesError: .decoding(path: "/biometric-service/heartRateZones/v2"))
        let (engine, container) = try makeEngine(fake, firstDay: today.adding(days: -2))

        let report = try await engine.run()

        #expect(report.dailyUpserted == 3)
        #expect(await engine.heartRateZones == nil)
        #expect(try fetch(SyncState.self, in: container).first?.firstLoadCompleted == true)
    }

    @Test func zonesUnauthorizedPropagates() async throws {
        let fake = FakeDataSource(dataDays: today.adding(days: -2)...today, zonesError: .unauthorized)
        let (engine, _) = try makeEngine(fake, firstDay: today.adding(days: -2))

        await #expect(throws: GarminAPIError.unauthorized) {
            try await engine.run()
        }
    }

    @Test func fitInvalidKeyPropagates() async throws {
        let activities = [
            FakeDataSource.activity(id: 30, typeKey: "running", day: today),
            FakeDataSource.activity(id: 31, typeKey: "running", day: today.adding(days: -1)),
        ]
        let fake = FakeDataSource(dataDays: today.adding(days: -2)...today, activities: activities, fitZip: try FITZipBuilder.run(seconds: 300), fitErrors: [30: .invalidKey])
        let (engine, container) = try makeEngine(fake, firstDay: today.adding(days: -2))

        await #expect(throws: GarminAPIError.invalidKey) {
            try await engine.run()
        }
        #expect(await fake.fitCalls == [30])
        #expect(try count(ActivityRecord.self, in: container) == 2)
        #expect(try count(DailyRecord.self, in: container) == 3)
        #expect(try fetch(SyncState.self, in: container).first?.firstLoadCompleted != true)
    }

    @Test func fitRateLimitStopsFitStepAndRunSucceeds() async throws {
        let activities = [
            FakeDataSource.activity(id: 40, typeKey: "running", day: today),
            FakeDataSource.activity(id: 41, typeKey: "running", day: today.adding(days: -1)),
            FakeDataSource.activity(id: 42, typeKey: "running", day: today.adding(days: -2)),
        ]
        let fake = FakeDataSource(dataDays: today.adding(days: -2)...today, activities: activities, fitZip: try FITZipBuilder.run(seconds: 300), fitErrors: [40: .rateLimited(path: "\(GarminEndpoints.fitDownloadPathPrefix)/40")])
        let (engine, container) = try makeEngine(fake, firstDay: today.adding(days: -2))

        let report = try await engine.run()

        #expect(await fake.fitCalls == [40])
        #expect(report.fitProcessed == 0)
        #expect(try fetch(ActivityRecord.self, in: container).allSatisfy { !$0.fitProcessed })
        #expect(try fetch(DailyRecord.self, in: container).allSatisfy { $0.readinessScore != nil })
        #expect(try fetch(SyncState.self, in: container).first?.firstLoadCompleted == true)
    }
}

@Suite struct SyncEngineResumeTests {
    private func cursors(_ state: SyncState) -> [String?] {
        [state.resumeDailyFrom, state.resumeHRVFrom, state.resumeSleepFrom, state.resumeBodyBatteryFrom, state.resumeActivityStart.map(String.init)]
    }

    @Test func firstLoadResumesActivitiesFromFailedPage() async throws {
        let firstDay = today.adding(days: -100)
        let fake = FakeDataSource(dataDays: firstDay...today, activities: spacedActivities(count: 160, perDay: 2))
        let (engine, container) = try makeEngine(fake, firstDay: firstDay)
        await fake.failActivities(start: 100)

        await #expect(throws: GarminAPIError.rateLimited(path: GarminEndpoints.activitiesPath)) {
            try await engine.run()
        }

        #expect(await fake.activityPageStarts == [0, 50, 100])
        let interrupted = try #require(try fetch(SyncState.self, in: container).first)
        #expect(interrupted.firstLoadCompleted == false)
        #expect(interrupted.resumeActivityStart == 100)
        let partialStart = today.adding(days: -3)
        let nextDay = partialStart.iso
        #expect(interrupted.resumeDailyFrom == nextDay)
        #expect(interrupted.resumeHRVFrom == nextDay)
        #expect(interrupted.resumeSleepFrom == nextDay)
        #expect(interrupted.resumeBodyBatteryFrom == nextDay)
        #expect(try count(ActivityRecord.self, in: container) == 100)

        await fake.failActivities(start: nil)
        let fromsBefore = await fake.froms.count
        let summaryBefore = await fake.summaryFroms.count
        let hrvBefore = await fake.hrvFroms.count
        let sleepBefore = await fake.sleepFroms.count
        let batteryBefore = await fake.batteryFroms.count

        let report = try await engine.run()

        #expect(Array(await fake.activityPageStarts.dropFirst(3)) == [100, 150])
        #expect(Array(await fake.summaryFroms.dropFirst(summaryBefore)) == [partialStart])
        #expect(Array(await fake.hrvFroms.dropFirst(hrvBefore)) == [partialStart])
        #expect(Array(await fake.sleepFroms.dropFirst(sleepBefore)) == [partialStart])
        #expect(Array(await fake.batteryFroms.dropFirst(batteryBefore)) == [partialStart])
        #expect(await fake.froms.count - fromsBefore == 6)
        #expect(report.activitiesUpserted == 60)
        #expect(try count(ActivityRecord.self, in: container) == 160)
        let state = try #require(try fetch(SyncState.self, in: container).first)
        #expect(state.firstLoadCompleted)
        #expect(cursors(state).allSatisfy { $0 == nil })
        #expect(try fetch(DailyRecord.self, in: container).allSatisfy { $0.readinessScore != nil })
    }

    @Test func resumeDaysLaterRereadsPartialToday() async throws {
        let firstDay = today.adding(days: -40)
        let later = today.adding(days: 5)
        let fake = FakeDataSource(dataDays: firstDay...later, activities: spacedActivities(count: 60, perDay: 2))
        let container = try TrainingSchema.container(inMemory: true)
        let interrupted = SyncEngine(source: fake, container: container, today: { today }, firstDay: firstDay)
        await fake.failActivities(start: 50)
        await #expect(throws: GarminAPIError.rateLimited(path: GarminEndpoints.activitiesPath)) {
            try await interrupted.run()
        }
        await fake.failActivities(start: nil)
        let summaryBefore = await fake.summaryFroms.count
        let hrvBefore = await fake.hrvFroms.count
        let sleepBefore = await fake.sleepFroms.count
        let batteryBefore = await fake.batteryFroms.count

        let resumed = SyncEngine(source: fake, container: container, today: { later }, firstDay: firstDay)
        _ = try await resumed.run()

        for froms in [
            Array(await fake.summaryFroms.dropFirst(summaryBefore)),
            Array(await fake.hrvFroms.dropFirst(hrvBefore)),
            Array(await fake.sleepFroms.dropFirst(sleepBefore)),
            Array(await fake.batteryFroms.dropFirst(batteryBefore)),
        ] {
            let first = try #require(froms.first)
            #expect(first <= today)
        }
        let records = Dictionary(uniqueKeysWithValues: try fetch(DailyRecord.self, in: container).map { ($0.day, $0) })
        #expect(records[later.iso]?.sleepSeconds == 27_000)
    }

    @Test func firstLoadResumesSleepFromFailedWindow() async throws {
        let firstDay = today.adding(days: -100)
        let fake = FakeDataSource(dataDays: firstDay...today, activities: spacedActivities(count: 10, perDay: 1))
        let (engine, container) = try makeEngine(fake, firstDay: firstDay)
        let sleepWindows = windows(from: firstDay, to: today, maxDays: 28).map(\.lowerBound)
        await fake.failSleep(from: sleepWindows[2])

        await #expect(throws: GarminAPIError.rateLimited(path: GarminEndpoints.sleepPath)) {
            try await engine.run()
        }

        let interrupted = try #require(try fetch(SyncState.self, in: container).first)
        let partialStart = today.adding(days: -3)
        let nextDay = partialStart.iso
        #expect(interrupted.firstLoadCompleted == false)
        #expect(interrupted.resumeDailyFrom == nextDay)
        #expect(interrupted.resumeHRVFrom == nextDay)
        #expect(interrupted.resumeSleepFrom == sleepWindows[2].iso)
        #expect(interrupted.resumeBodyBatteryFrom == nil)
        #expect(interrupted.resumeActivityStart == nil)
        #expect(await fake.batteryFroms.isEmpty)
        #expect(await fake.activityPageStarts.isEmpty)

        await fake.failSleep(from: nil)
        let summaryBefore = await fake.summaryFroms.count
        let hrvBefore = await fake.hrvFroms.count
        let sleepBefore = await fake.sleepFroms.count

        _ = try await engine.run()

        #expect(Array(await fake.summaryFroms.dropFirst(summaryBefore)) == [partialStart])
        #expect(Array(await fake.hrvFroms.dropFirst(hrvBefore)) == [partialStart])
        #expect(Array(await fake.sleepFroms.dropFirst(sleepBefore)) == Array(sleepWindows.dropFirst(2)))
        #expect(await fake.batteryFroms == sleepWindows)
        #expect(await fake.activityPageStarts == [0])
        let state = try #require(try fetch(SyncState.self, in: container).first)
        #expect(state.firstLoadCompleted)
        #expect(cursors(state).allSatisfy { $0 == nil })
        let records = try fetch(DailyRecord.self, in: container)
        #expect(records.count == fake.dayCount)
        #expect(records.allSatisfy { $0.sleepSeconds == 27_000 && $0.hrvLastNight == 60 && $0.restingHR == 50 })
        #expect(records.allSatisfy { $0.bodyBatteryMorningMax == 85 })
        #expect(records.allSatisfy { $0.readinessScore != nil })
    }
}
