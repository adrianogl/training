import FITReader
import Foundation
import Storage
import SwiftData
import Sync
import Testing
import TrainingCore
@testable import HealthImport

private struct Reader: HealthReading {
    let runStart: Date
    let today: Day

    var run: HealthWorkout {
        HealthWorkout(id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!, kind: .run, start: runStart, end: runStart.addingTimeInterval(1800),
                      duration: 1800, distanceMeters: 5000, averageHeartRate: 152, maxHeartRate: 175)
    }

    func workouts(from: Date, to: Date) async throws -> [HealthWorkout] { [run].filter { $0.start >= from && $0.start <= to } }

    func series(for workout: HealthWorkout) async throws -> HealthSeries {
        HealthSeries(
            heartRate: (0...360).map { HealthPoint(date: runStart.addingTimeInterval(Double($0) * 5), value: 150) },
            distance: (1...30).map { HealthPoint(date: runStart.addingTimeInterval(Double($0) * 60), value: 5000.0 / 30) }
        )
    }

    func restingHeartRate(from: Day, to: Day) async throws -> [Day: Double] { [today: 51] }
    func nightlyHRV(from: Day, to: Day) async throws -> [Day: Double] { [today: 48] }
    func sleep(from: Day, to: Day) async throws -> [HealthSleepNight] {
        [HealthSleepNight(day: today, end: runStart.addingTimeInterval(-3 * 3600), asleepSeconds: 7 * 3600, deepSeconds: 3600, remSeconds: 5400, coreSeconds: 16_200, awakeSeconds: 600)]
    }
}

@Suite struct HealthSyncTests {
    @Test func syncEngineImportsAppleWatchData() async throws {
        let today = Day.today()
        let runStart = Calendar.current.date(byAdding: .hour, value: 7, to: Calendar.current.startOfDay(for: .now)) ?? .now
        let container = try TrainingSchema.container(inMemory: true)
        let source = HealthDataSource(reader: Reader(runStart: runStart, today: today), now: { runStart.addingTimeInterval(7200) })
        let engine = SyncEngine(source: source, container: container, today: { today }, firstDay: today.adding(days: -30))

        _ = try await engine.run()

        let context = ModelContext(container)
        let activity = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(activity.typeKey == "running")
        #expect(activity.fitProcessed)
        #expect(activity.activityTrainingLoad != nil)
        let samples = try #require(activity.samplesData.flatMap(FITSampleCoding.decode))
        #expect(samples.count == 361)
        let daily = try #require(try context.fetch(FetchDescriptor<DailyRecord>()).first { $0.day == today.iso })
        #expect(daily.restingHR == 51)
        #expect(daily.hrvLastNight == 48)
        #expect(daily.sleepScore != nil)
        #expect(daily.bodyBatteryMorningMax == nil)
    }
}
