import FITReader
import Foundation
import GarminAPI
import Testing
import TrainingCore
@testable import HealthImport

private let start = Date(timeIntervalSince1970: 1_795_000_000)

private func run(minutes: Double = 10, id: UUID = UUID()) -> HealthWorkout {
    HealthWorkout(
        id: id, kind: .run, start: start, end: start.addingTimeInterval(minutes * 60), duration: minutes * 60,
        distanceMeters: minutes * 200, averageHeartRate: 150, maxHeartRate: 172, vo2max: 51
    )
}

private struct FakeReader: HealthReading {
    var items: [HealthWorkout]
    var series = HealthSeries()
    var resting: [Day: Double] = [:]
    var hrv: [Day: Double] = [:]
    var nights: [HealthSleepNight] = []

    func workouts(from: Date, to: Date) async throws -> [HealthWorkout] { items.filter { $0.start >= from && $0.start <= to } }
    func series(for workout: HealthWorkout) async throws -> HealthSeries { series }
    func restingHeartRate(from: Day, to: Day) async throws -> [Day: Double] { resting.filter { $0.key >= from && $0.key <= to } }
    func nightlyHRV(from: Day, to: Day) async throws -> [Day: Double] { hrv.filter { $0.key >= from && $0.key <= to } }
    func sleep(from: Day, to: Day) async throws -> [HealthSleepNight] { nights.filter { $0.day >= from && $0.day <= to } }
}

@Suite struct HealthMappingTests {
    @Test func activityIdIsStableAndAboveGarminRange() {
        let id = UUID()
        #expect(HealthMapping.activityId(id) == HealthMapping.activityId(id))
        #expect(HealthMapping.activityId(id) > 1_000_000_000_000_000_000)
        #expect(HealthMapping.activityId(UUID()) != HealthMapping.activityId(id))
    }

    @Test func trimpGrowsWithIntensity() throws {
        let easy = try #require(HealthMapping.trimp(durationSeconds: 3600, averageHeartRate: 135, resting: 55, maximum: 190))
        let hard = try #require(HealthMapping.trimp(durationSeconds: 3600, averageHeartRate: 165, resting: 55, maximum: 190))
        #expect(hard > easy)
        #expect(HealthMapping.trimp(durationSeconds: 3600, averageHeartRate: 150, resting: 60, maximum: 190) == 100)
        #expect(HealthMapping.trimp(durationSeconds: 3600, averageHeartRate: nil, resting: 60, maximum: 190) == nil)
    }

    @Test func hrvBaselineNeedsTwoWeeks() throws {
        #expect(HealthMapping.hrvBaseline(Array(repeating: 45, count: 13)) == nil)
        let baseline = try #require(HealthMapping.hrvBaseline((0..<20).map { 40 + Double($0 % 5) * 2.5 }))
        #expect(baseline.lowUpper < baseline.balancedLow)
        #expect(baseline.balancedLow < baseline.balancedUpper)
        #expect(HealthMapping.hrvStatus(baseline.balancedLow + 0.1, baseline: baseline) == "BALANCED")
        #expect(HealthMapping.hrvStatus(baseline.lowUpper - 1, baseline: baseline) == "LOW")
    }

    @Test func sleepScoreWeighsDurationAndStages() {
        let full = HealthSleepNight(day: Day(iso: "2026-11-18")!, end: start, asleepSeconds: 8 * 3600, deepSeconds: 1.6 * 3600, remSeconds: 1.6 * 3600, coreSeconds: 4.8 * 3600, awakeSeconds: 600)
        let short = HealthSleepNight(day: Day(iso: "2026-11-18")!, end: start, asleepSeconds: 6 * 3600, deepSeconds: 0.75 * 3600, remSeconds: 0.75 * 3600, coreSeconds: 4.5 * 3600, awakeSeconds: 900)
        #expect(HealthMapping.sleepScore(full) == 100)
        #expect(HealthMapping.sleepScore(short) == 71)
    }

    @Test func summaryResamplesDistanceRouteAndLaps() throws {
        let workout = run()
        let distance = (1...10).map { HealthPoint(date: start.addingTimeInterval(Double($0) * 60), value: 200) }
        let route = (0...10).map { HealthRoutePoint(date: start.addingTimeInterval(Double($0) * 60), latitude: -19.9 + Double($0) * 0.001, longitude: -43.9, altitude: 850) }
        let heart = (0...120).map { HealthPoint(date: start.addingTimeInterval(Double($0) * 5), value: 140 + Double($0 % 10)) }
        let laps = [HealthLap(start: start, end: start.addingTimeInterval(300)), HealthLap(start: start.addingTimeInterval(300), end: start.addingTimeInterval(600))]
        let summary = HealthMapping.summary(workout, series: HealthSeries(heartRate: heart, distance: distance, route: route, laps: laps))
        #expect(summary.samples.count == 121)
        let middle = try #require(summary.samples.first { $0.t == 300 })
        #expect(abs((middle.distance ?? 0) - 1000) < 0.01)
        #expect(abs((middle.speed ?? 0) - 200.0 / 60) < 0.01)
        #expect(middle.altitude == 850)
        #expect(summary.structure.laps.map { Int($0.distance.rounded()) } == [1000, 1000])
        #expect(summary.physio?.vo2max == 51)
        #expect(summary.route.count == 11)
    }
}

@Suite struct HealthDataSourceTests {
    @Test func activitiesPageNewestFirstWithLoad() async throws {
        let older = HealthWorkout(id: UUID(), kind: .strength, start: start.addingTimeInterval(-86_400), end: start.addingTimeInterval(-82_800), duration: 3600, averageHeartRate: 110, maxHeartRate: 140)
        let source = HealthDataSource(reader: FakeReader(items: [older, run()]), now: { start.addingTimeInterval(3600) })
        let first = try await source.activities(start: 0, limit: 1, from: nil, to: nil)
        let second = try await source.activities(start: 1, limit: 1, from: nil, to: nil)
        #expect(first.first?.typeKey == "running")
        #expect(first.first?.activityTrainingLoad != nil)
        #expect(second.first?.typeKey == "strength_training")
        #expect(try await source.activities(start: 2, limit: 1, from: nil, to: nil).isEmpty)
    }

    @Test func runDetailComesFromSeriesAndStrengthHasNone() async throws {
        let workout = run()
        let strength = HealthWorkout(id: UUID(), kind: .strength, start: start.addingTimeInterval(-7200), end: start.addingTimeInterval(-3600), duration: 3600)
        let reader = FakeReader(items: [workout, strength], series: HealthSeries(distance: [HealthPoint(date: start.addingTimeInterval(600), value: 2000)]))
        let source = HealthDataSource(reader: reader, now: { start.addingTimeInterval(3600) })
        let summary = try #require(try await source.activitySummary(activityId: HealthMapping.activityId(workout.id)))
        #expect(summary.samples.last?.distance == 2000)
        #expect(try await source.activitySummary(activityId: HealthMapping.activityId(strength.id)) == nil)
    }

    @Test func hrvGetsOwnBaselineAfterTwoWeeks() async throws {
        let today = Day(iso: "2026-11-18")!
        var hrv: [Day: Double] = [:]
        for offset in 0..<30 { hrv[today.adding(days: -offset)] = 40 + Double(offset % 6) }
        let source = HealthDataSource(reader: FakeReader(items: [], hrv: hrv))
        let summaries = try await source.hrvSummaries(from: today.adding(days: -2), to: today)
        #expect(summaries.count == 3)
        #expect(summaries.allSatisfy { $0.baselineBalancedLow != nil })
        let early = try await source.hrvSummaries(from: today.adding(days: -29), to: today.adding(days: -29))
        #expect(early.first?.baselineBalancedLow == nil)
    }

    @Test func noBodyBatteryAndRestingHeartRateBecomesDaily() async throws {
        let day = Day(iso: "2026-11-18")!
        let source = HealthDataSource(reader: FakeReader(items: [], resting: [day: 52.4]))
        #expect(try await source.bodyBattery(from: day, to: day).isEmpty)
        #expect(try await source.dailySummaries(from: day, to: day).first?.restingHeartRate == 52)
    }
}
