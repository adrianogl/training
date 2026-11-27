import FITReader
import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Sync

private let today = Day(iso: "2026-11-27")!

private func estimate(_ day: String, _ heartRate: Int) -> ThresholdHistoryRecord {
    ThresholdHistoryRecord(sport: SyncConstants.thresholdEstimateSport, day: day, heartRate: heartRate)
}

private func thresholdRun(id: Int64, day: Day, heartRate: Int, peak: Int) throws -> ActivityRecord {
    let steps = [
        PrescribedStep(index: 0, intensity: .warmup, duration: .distance(meters: 3_000), target: .open),
        PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 4_000), target: .speed(low: 3.2, high: 3.5)),
    ]
    let laps = [
        LapSummary(stepIndex: 0, intensity: .warmup, startOffset: 0, timerSeconds: 900, distance: 3_000),
        LapSummary(stepIndex: 1, intensity: .active, startOffset: 900, timerSeconds: 1_200, distance: 4_000),
    ]
    let structure = WorkoutStructure(prescription: WorkoutPrescription(name: "Limiar 4 km", steps: steps), laps: laps)
    let samples = (0..<2_100).map { second in
        let t = Double(second)
        let rate = second < 900 ? 140 : second < 1_500 ? heartRate - 6 : (2_000..<2_010).contains(second) ? peak : heartRate
        return FITSample(t: t, heartRate: rate, distance: t * 3.34)
    }
    return ActivityRecord(
        activityId: id, typeKey: "running", name: "Limiar 4 km",
        start: Date(timeIntervalSince1970: 1_790_000_000 + Double(id) * 86_400), distance: 7_000,
        samplesData: try JSONEncoder().encode(samples), fitProcessed: true, localDay: day.iso,
        structureData: try JSONEncoder().encode(structure)
    )
}

@Suite struct ThresholdEstimatesTests {
    @Test func currentThresholdIsTheMedianOfTheLastFourEstimates() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        [estimate("2026-10-20", 150), estimate("2026-11-03", 168), estimate("2026-11-10", 164), estimate("2026-11-17", 166), estimate("2026-11-24", 168)]
            .forEach(context.insert)
        try context.save()

        #expect(try thresholdHeartRate(on: today, in: context) == 167)
    }

    @Test func pastRunUsesTheEstimatesUpToItsDay() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        [estimate("2026-10-01", 160), estimate("2026-10-08", 162), estimate("2026-11-10", 170)].forEach(context.insert)
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: "2026-10-05", heartRate: 175))
        try context.save()

        #expect(try thresholdHeartRate(on: Day(iso: "2026-10-05")!, in: context) == 160)
        #expect(try thresholdHeartRate(on: Day(iso: "2026-10-20")!, in: context) == 161)
        #expect(try thresholdHeartRate(on: Day(iso: "2026-09-01")!, in: context) == 160)
        #expect(try thresholdHeartRate(on: today, in: context) == 162)
    }

    @Test func fitThresholdIsOnlyTheFallbackUntilTheFirstEstimate() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: "2026-10-05", heartRate: 175))
        try context.save()
        #expect(try thresholdHeartRate(on: today, in: context) == 175)

        context.insert(estimate("2026-11-20", 166))
        try context.save()
        #expect(try thresholdHeartRate(on: today, in: context) == 166)
    }

    @Test func refreshEstimatesTheThresholdRunAndRecomputesItsZones() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: today.adding(days: -2).iso, heartRate: 175))
        context.insert(try thresholdRun(id: 1, day: today.adding(days: -2), heartRate: 168, peak: 188))
        try context.save()

        _ = try refreshThresholdZoneSeconds(in: context)

        let run = try #require(try context.fetch(FetchDescriptor<ActivityRecord>()).first)
        #expect(run.thresholdUsed == 168)
        #expect(try estimatedMaxHeartRate(on: today, in: context) == 188)
        let estimateSport = SyncConstants.thresholdEstimateSport
        let stored = try context.fetch(FetchDescriptor<ThresholdHistoryRecord>(predicate: #Predicate { $0.sport == estimateSport }))
        #expect(stored.map(\.heartRate) == [168])
    }

    @Test func weatherArrivingLaterDiscardsTheEstimateOfAHotRun() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        let run = try thresholdRun(id: 1, day: today.adding(days: -1), heartRate: 168, peak: 188)
        context.insert(run)
        try context.save()
        _ = try refreshThresholdZoneSeconds(in: context, changed: [1])
        #expect(try thresholdHeartRate(on: today, in: context) == 168)

        run.weatherTemperature = 34
        run.weatherDewPoint = 26
        run.weatherCheckedAt = .now
        try context.save()
        _ = try refreshThresholdZoneSeconds(in: context, changed: [1])

        #expect(try thresholdHeartRate(on: today, in: context) == nil)
        #expect(run.thresholdUsed == nil)
        #expect(try estimatedMaxHeartRate(on: today, in: context) == 188)
    }

    @Test func refreshLeavesOneEstimateAndOneMaxPerDay() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        let day = today.adding(days: -1)
        context.insert(try thresholdRun(id: 1, day: day, heartRate: 168, peak: 188))
        context.insert(estimate(day.iso, 150))
        context.insert(estimate(day.iso, 150))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.maxHeartRateSport, day: day.iso, heartRate: 170))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.maxHeartRateSport, day: day.iso, heartRate: 170))
        try context.save()

        try refreshThresholdEstimates(in: context, changed: [1])
        try refreshThresholdEstimates(in: ModelContext(container), changed: [1])

        let records = try ModelContext(container).fetch(FetchDescriptor<ThresholdHistoryRecord>())
        #expect(records.filter { $0.sport == SyncConstants.thresholdEstimateSport }.map(\.heartRate) == [168])
        #expect(records.filter { $0.sport == SyncConstants.maxHeartRateSport }.map(\.heartRate) == [188])
    }

    @Test func medianCountsDaysAndNotDuplicatedRecords() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        [estimate("2026-11-03", 160), estimate("2026-11-10", 164), estimate("2026-11-17", 166), estimate("2026-11-24", 180), estimate("2026-11-24", 180)]
            .forEach(context.insert)
        try context.save()

        #expect(try thresholdHeartRate(on: today, in: context) == 165)
    }

    @Test func hotRunLeftWithAnEstimateIsReevaluatedWithoutChangedIds() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        let day = today.adding(days: -1)
        let run = try thresholdRun(id: 1, day: day, heartRate: 168, peak: 188)
        run.weatherTemperature = 34
        run.weatherDewPoint = 26
        run.weatherCheckedAt = .now
        context.insert(run)
        context.insert(estimate(day.iso, 168))
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.maxHeartRateSport, day: day.iso, heartRate: 188))
        try context.save()

        try refreshThresholdEstimates(in: context)

        let records = try context.fetch(FetchDescriptor<ThresholdHistoryRecord>())
        #expect(records.filter { $0.sport == SyncConstants.thresholdEstimateSport }.isEmpty)
        #expect(records.filter { $0.sport == SyncConstants.maxHeartRateSport }.map(\.heartRate) == [188])
    }

    @Test func refreshDropsEstimatesOfDeletedRuns() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        context.insert(estimate(today.adding(days: -3).iso, 170))
        try context.save()

        _ = try refreshThresholdZoneSeconds(in: context)

        #expect(try thresholdHeartRate(on: today, in: context) == nil)
    }

    @Test func maxHeartRateLooksBackTwelveMonths() throws {
        let context = ModelContext(try TrainingSchema.container(inMemory: true))
        let sport = SyncConstants.maxHeartRateSport
        context.insert(ThresholdHistoryRecord(sport: sport, day: today.adding(days: -400).iso, heartRate: 195))
        context.insert(ThresholdHistoryRecord(sport: sport, day: today.adding(days: -100).iso, heartRate: 187))
        context.insert(ThresholdHistoryRecord(sport: sport, day: today.adding(days: -10).iso, heartRate: 182))
        context.insert(ThresholdHistoryRecord(sport: sport, day: today.adding(days: -5).iso, heartRate: 0))
        try context.save()

        #expect(try estimatedMaxHeartRate(on: today, in: context) == 187)
        #expect(try estimatedMaxHeartRate(on: today.adding(days: -200), in: context) == 195)
    }
}
