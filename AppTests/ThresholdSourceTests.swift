import Foundation
import Insights
import Storage
import SwiftData
import Sync
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct ThresholdSourceTests {
    private typealias F = WorkoutDetailFixtures

    private func context() throws -> (ModelContext, ActivityRecord, Day) {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(HeartRateZonesRecord(
            sport: "DEFAULT", zone1Floor: 100, zone2Floor: 120, zone3Floor: 140, zone4Floor: 160, zone5Floor: 175,
            maxHeartRate: 190, lactateThresholdHeartRate: 150
        ))
        context.insert(HeartRateZonesRecord(
            sport: "running", zone1Floor: 100, zone2Floor: 124, zone3Floor: 137, zone4Floor: 148, zone5Floor: 154,
            maxHeartRate: 188, lactateThresholdHeartRate: 160
        ))
        let run = F.run(id: 1, meters: 8_000, structure: F.freeStructure(kilometers: 8))
        context.insert(run)
        try context.save()
        return (context, run, try #require(run.localDay.flatMap(Day.init(iso:))))
    }

    private func resolved(_ context: ModelContext, run: ActivityRecord, day: Day) throws -> (sync: Int?, insights: Double?, app: Int?) {
        let series = try metricSeries(.thresholdHeartRate, context: context, today: day, period: .sixMonths)
        let inputs = WorkoutAnalysisContext.inputs(records: [run], in: context)
        return (try thresholdHeartRate(on: day, in: context), series.points.last?.1, inputs.thresholdByDay[day])
    }

    @Test func syncInsightsAndAppAgreeOnZonesRecordThreshold() throws {
        let (context, run, day) = try context()

        let threshold = try resolved(context, run: run, day: day)

        #expect(threshold.sync == 160)
        #expect(threshold.insights == 160)
        #expect(threshold.app == 160)
        #expect(WorkoutAnalysisContext.inputs(records: [run], in: context).watchZones?.floors == [100, 124, 137, 148, 154])
    }

    @Test func syncInsightsAndAppAgreeOnFitThreshold() throws {
        let (context, run, day) = try context()
        context.insert(ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: day.iso, heartRate: 171))
        try context.save()

        let threshold = try resolved(context, run: run, day: day)

        #expect(threshold.sync == 171)
        #expect(threshold.insights == 171)
        #expect(threshold.app == 171)
    }
}
