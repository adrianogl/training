import TrainingCore
import FITReader
import Foundation
import Storage
import SwiftData
import Testing
import WorkoutAnalysis
@testable import trAIning

@Suite struct ChartDataTests {
    @Test func heartRateSeriesSkipsNil() {
        let samples = [
            FITSample(t: 0, heartRate: 120),
            FITSample(t: 1),
            FITSample(t: 2, heartRate: 130),
            FITSample(t: 3, speed: 3),
            FITSample(t: 4, heartRate: 140),
        ]

        let series = ChartData.heartRateSeries(samples)

        #expect(series.map { $0.t } == [0, 2, 4])
        #expect(series.map { $0.bpm } == [120, 130, 140])
    }

    @Test func zoneSharesSumToOne() throws {
        let shares = ChartData.zoneShares([60, 120, 600, 300, 120])

        try #require(shares.count == 5)
        #expect(abs(shares.reduce(0, +) - 1) < 1e-9)
        #expect(abs(shares[2] - 600.0 / 1_200) < 1e-9)

        let zeros = ChartData.zoneShares([0, 0, 0, 0, 0])
        #expect(zeros == [0, 0, 0, 0, 0])
        #expect(zeros.allSatisfy { !$0.isNaN })
        #expect(ChartData.zoneShares([]).isEmpty)
    }

    @Test func heartRateSeriesDropsNonPositiveAndSortsByTime() {
        let samples = [
            FITSample(t: 5, heartRate: 150),
            FITSample(t: 1, heartRate: 0),
            FITSample(t: 3, heartRate: 140),
            FITSample(t: 2, heartRate: -4),
            FITSample(t: 0, heartRate: 110),
        ]

        let series = ChartData.heartRateSeries(samples)

        #expect(series.map { $0.t } == [0, 3, 5])
        #expect(series.map { $0.bpm } == [110, 140, 150])
    }

    @Test func thinnedKeepsExtremesAndCapsCount() {
        let values = (0..<5_000).map { index -> (t: Double, bpm: Int) in
            let bpm = index == 2_345 ? 199 : index == 3_001 ? 61 : 120 + index % 7
            return (t: Double(index), bpm: bpm)
        }

        let thinned = ChartData.thinned(values, limit: 600) { Double($0.bpm) }

        #expect(thinned.count <= 600)
        #expect(thinned.count > 300)
        #expect(thinned.map { $0.bpm }.max() == 199)
        #expect(thinned.map { $0.bpm }.min() == 61)
        #expect(thinned.map { $0.t } == thinned.map { $0.t }.sorted())
        #expect(ChartData.thinned(Array(values.prefix(10)), limit: 600) { Double($0.bpm) }.count == 10)
    }

    @Test func activeSpansFollowActiveLaps() {
        func block(_ kind: BlockKind, _ laps: [LapSummary]) -> WorkoutBlock {
            WorkoutBlock(
                kind: kind, ordinal: 1, label: "", prescribed: nil, laps: laps, seconds: 0, distance: 0,
                avgSpeed: nil, avgHeartRate: nil, maxHeartRate: nil, dominantZone: nil, status: .noTarget
            )
        }
        let blocks = [
            block(.warmup, [LapSummary(startOffset: 0, timerSeconds: 300, distance: 1_000)]),
            block(.active, [
                LapSummary(startOffset: 320, timerSeconds: 250, distance: 1_000),
                LapSummary(startOffset: 600, timerSeconds: 0, distance: 0),
                LapSummary(startOffset: 610, timerSeconds: 248, distance: 1_000),
            ]),
            block(.recovery, [LapSummary(startOffset: 860, timerSeconds: 120, distance: 300)]),
            block(.active, [LapSummary(startOffset: 1_000, timerSeconds: -1, distance: 0)]),
        ]

        let spans = ChartData.activeSpans(blocks)

        #expect(spans == [BlockSpan(start: 320, end: 570), BlockSpan(start: 610, end: 858)])
    }

    @Test func zoneBandsUseHighestCeiling() {
        let zones = HeartRateZones(floors: [100, 120, 140, 155, 170], maxHeartRate: 185)

        let bands = ChartData.zoneBands(zones, ceiling: 192)

        #expect(bands.map(\.zone) == [1, 2, 3, 4, 5])
        #expect(bands.map(\.low) == [100, 120, 140, 155, 170])
        #expect(bands.map(\.high) == [120, 140, 155, 170, 192])
        #expect(ChartData.zoneBands(zones, ceiling: 150).last?.high == 185)
        #expect(ChartData.zoneBands(HeartRateZones(floors: []), ceiling: 150).isEmpty)
        #expect(ChartData.zoneBands(nil, ceiling: 150).isEmpty)
    }

    @Test func altitudeSeriesSkipsNilAndNonFinite() {
        let samples = [
            FITSample(t: 0, altitude: 850),
            FITSample(t: 1),
            FITSample(t: 2, altitude: .nan),
            FITSample(t: 3, altitude: .infinity),
            FITSample(t: 4, altitude: 852),
        ]

        let series = ChartData.altitudeSeries(samples)

        #expect(series.map { $0.t } == [0, 4])
        #expect(series.map { $0.meters } == [850, 852])
    }

    @Test func routePointsDropInvalidCoordinates() {
        let route = [
            Coordinate(lat: -19.85, lon: -43.97),
            Coordinate(lat: 0, lon: 0),
            Coordinate(lat: .nan, lon: -43.9),
            Coordinate(lat: 91, lon: 10),
            Coordinate(lat: -19.86, lon: -43.98),
        ]

        #expect(ChartData.routePoints(route) == [Coordinate(lat: -19.85, lon: -43.97), Coordinate(lat: -19.86, lon: -43.98)])
    }

    @MainActor
    @Test func summaryOmitsKindWhenEqualToTitle() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(ActivityRecord(
            activityId: 9, typeKey: "strength_training", name: "MMII (quarta)", start: WorkoutDetailFixtures.base,
            duration: 1_640, averageHR: 100, maxHR: 143, activityTrainingLoad: 15, zoneSeconds: [480, 60, 0, 0, 0]
        ))
        try context.save()

        let model = WorkoutDetailModel(activityId: 9, context: context)

        #expect(model.summary?.title == "MMII (quarta)")
        #expect(model.summary?.subtitle == "")
        #expect(model.zoneShares.map(\.zone) == [1, 2, 3, 4, 5])
    }
}
