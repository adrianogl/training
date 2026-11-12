import FITReader
import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct ZoneRulerTests {
    private typealias F = WorkoutDetailFixtures

    private let watchZones = HeartRateZones(floors: [100, 120, 140, 160, 175], maxHeartRate: 190)
    private let watchSeconds: [Double] = [60, 300, 1_200, 1_500, 120]
    private let thresholdSeconds: [Double] = [300, 1_700, 1_300, 160, 0]

    private func zonesRecord(threshold: Int?) -> HeartRateZonesRecord {
        HeartRateZonesRecord(
            sport: "DEFAULT", zone1Floor: 100, zone2Floor: 120, zone3Floor: 140, zone4Floor: 160, zone5Floor: 175,
            maxHeartRate: 190, lactateThresholdHeartRate: threshold
        )
    }

    private func model(
        threshold: Int?, thresholdUsed: Int?, thresholdSeconds: [Double], activityFloors: [Int] = [], samples: [FITSample]? = nil
    ) throws -> WorkoutDetailModel {
        try analyzed(threshold: threshold, thresholdUsed: thresholdUsed, thresholdSeconds: thresholdSeconds, activityFloors: activityFloors, samples: samples).model
    }

    private func analyzed(
        threshold: Int?, thresholdUsed: Int?, thresholdSeconds: [Double], activityFloors: [Int] = [], samples: [FITSample]? = nil
    ) throws -> (model: WorkoutDetailModel, analysis: WorkoutAnalysisContext) {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(zonesRecord(threshold: threshold))
        let run = F.run(id: 1, meters: 8_000, structure: F.freeStructure(kilometers: 8), samples: samples)
        run.zoneSeconds = watchSeconds
        run.thresholdZoneSeconds = thresholdSeconds
        run.thresholdUsed = thresholdUsed
        run.watchZoneFloors = activityFloors
        context.insert(run)
        try context.save()
        return (WorkoutDetailModel(activityId: 1, context: context), WorkoutAnalysisContext.build(record: run, records: [run], in: context))
    }

    @Test func rulerShowsBothBarsWithThreshold() throws {
        let ruler = try #require(try model(threshold: 170, thresholdUsed: 170, thresholdSeconds: thresholdSeconds).ruler)

        #expect(ruler.watch == ZoneBar(floors: [100, 120, 140, 160, 175], seconds: watchSeconds))
        #expect(ruler.threshold == ZoneBar(floors: [0, 145, 153, 162, 170], seconds: thresholdSeconds))
        #expect(ruler.thresholdHeartRate == 170)
        #expect(ruler.divergence == 5)
        #expect(ruler.thresholdTitle == "Pelo limiar (170 bpm)")
    }

    @Test func rulerWatchOnlyWithoutSamples() throws {
        let ruler = try #require(try model(threshold: 170, thresholdUsed: 170, thresholdSeconds: []).ruler)

        #expect(ruler.watch.seconds == watchSeconds)
        #expect(ruler.threshold == nil)
        #expect(ruler.thresholdHeartRate == 170)
        #expect(ruler.divergence == 5)
    }

    @Test func rulerWatchOnlyWithoutThreshold() throws {
        let ruler = try #require(try model(threshold: nil, thresholdUsed: nil, thresholdSeconds: []).ruler)

        #expect(ruler.watch.floors == [100, 120, 140, 160, 175])
        #expect(ruler.threshold == nil)
        #expect(ruler.thresholdHeartRate == nil)
        #expect(ruler.divergence == nil)
        #expect(ruler.note == "sem FC de limiar no Garmin")
    }

    @Test func rulerUsesActivityWatchFloors() throws {
        let ruler = try #require(try model(
            threshold: 170, thresholdUsed: 170, thresholdSeconds: thresholdSeconds, activityFloors: [110, 130, 140, 150, 160]
        ).ruler)

        #expect(ruler.watch.floors == [110, 130, 140, 150, 160])
        #expect(ruler.thresholdHeartRate == 170)
        #expect(ruler.divergence == -10)
        #expect(ruler.note == "Zonas do relógio 10 bpm abaixo do limiar")
    }

    @Test func rulerAndBlocksUseTheThresholdOfTheDay() throws {
        let (model, analysis) = try analyzed(
            threshold: 150, thresholdUsed: 170, thresholdSeconds: thresholdSeconds, samples: F.samples(kilometers: 8, secondsPerKm: 330)
        )
        let ruler = try #require(model.ruler)

        #expect(analysis.thresholdHeartRate == 150)
        #expect(ruler.thresholdHeartRate == 150)
        #expect(ruler.threshold?.floors == analysis.zones?.floors)
        #expect(ruler.threshold?.floors == [0, 128, 135, 143, 150])
        #expect(ruler.threshold?.seconds != thresholdSeconds)
    }

    @Test func runWithoutThresholdUsesActivityFloorsInRulerAndBlocks() throws {
        let floors = [110, 130, 140, 150, 160]
        let (model, analysis) = try analyzed(threshold: nil, thresholdUsed: nil, thresholdSeconds: [], activityFloors: floors)
        let ruler = try #require(model.ruler)

        #expect(ruler.watch.floors == floors)
        #expect(analysis.zones?.floors == floors)
        #expect(analysis.zones?.maxHeartRate == 190)
    }

    @Test func rulerFallsBackToZonesRecordFloors() throws {
        let ruler = try #require(try model(
            threshold: 170, thresholdUsed: 170, thresholdSeconds: thresholdSeconds, activityFloors: [110, 130]
        ).ruler)

        #expect(ruler.watch.floors == [100, 120, 140, 160, 175])
        #expect(ruler.divergence == 5)
    }

    @Test func divergenceTextBelowAndAbove() throws {
        let below = try #require(ZoneRulerData.make(
            watchZones: HeartRateZones(floors: [100, 124, 137, 148, 154]), watchSeconds: watchSeconds,
            thresholdHeartRate: 160, thresholdSeconds: thresholdSeconds
        ))
        let above = try #require(ZoneRulerData.make(
            watchZones: watchZones, watchSeconds: watchSeconds, thresholdHeartRate: 170, thresholdSeconds: thresholdSeconds
        ))
        let close = try #require(ZoneRulerData.make(
            watchZones: watchZones, watchSeconds: watchSeconds, thresholdHeartRate: 173, thresholdSeconds: thresholdSeconds
        ))

        #expect(below.divergence == -6)
        #expect(below.note == "Zonas do relógio 6 bpm abaixo do limiar")
        #expect(above.note == "Zonas do relógio 5 bpm acima do limiar")
        #expect(close.divergence == nil)
        #expect(close.note == nil)
    }

    @Test func rulerNeedsWatchZonesAndTime() {
        #expect(ZoneRulerData.make(watchZones: nil, watchSeconds: watchSeconds, thresholdHeartRate: 170, thresholdSeconds: thresholdSeconds) == nil)
        #expect(ZoneRulerData.make(watchZones: watchZones, watchSeconds: [], thresholdHeartRate: nil, thresholdSeconds: []) == nil)
    }

    @Test func rangeWidensForLowFloorAndHighThreshold() throws {
        let standard = try #require(ZoneRulerData.make(
            watchZones: HeartRateZones(floors: [100, 124, 137, 148, 154]), watchSeconds: watchSeconds,
            thresholdHeartRate: 160, thresholdSeconds: thresholdSeconds
        ))
        let wide = try #require(ZoneRulerData.make(
            watchZones: HeartRateZones(floors: [92, 120, 140, 160, 178]), watchSeconds: watchSeconds,
            thresholdHeartRate: 176, thresholdSeconds: thresholdSeconds
        ))

        #expect(standard.range == 100...180)
        #expect(wide.range == 92...188)
    }

    @Test func segmentsAndMarksFollowFloors() {
        let bar = ZoneBar(floors: [100, 124, 137, 148, 154], seconds: watchSeconds)
        let threshold = ZoneBar(floors: [0, 136, 144, 152, 160], seconds: thresholdSeconds)

        #expect(bar.segments(in: 100...180) == [
            ZoneSegment(zone: 1, start: 0, end: 0.3),
            ZoneSegment(zone: 2, start: 0.3, end: 0.4625),
            ZoneSegment(zone: 3, start: 0.4625, end: 0.6),
            ZoneSegment(zone: 4, start: 0.6, end: 0.675),
            ZoneSegment(zone: 5, start: 0.675, end: 1),
        ])
        #expect(bar.marks(in: 100...180) == [
            ZoneMark(id: 0, bpm: 100, position: 0),
            ZoneMark(id: 1, bpm: 124, position: 0.3),
            ZoneMark(id: 2, bpm: 137, position: 0.4625),
            ZoneMark(id: 3, bpm: 148, position: 0.6),
            ZoneMark(id: 4, bpm: 154, position: 0.675),
        ])
        #expect(threshold.segments(in: 100...180).first == ZoneSegment(zone: 1, start: 0, end: 0.45))
        #expect(threshold.marks(in: 100...180).map(\.bpm) == [136, 144, 152, 160])
    }

    @Test func repeatedFloorsGetDistinctMarkIds() throws {
        let ruler = try #require(ZoneRulerData.make(
            watchZones: HeartRateZones(floors: [100, 124, 137, 148, 148]), watchSeconds: watchSeconds,
            thresholdHeartRate: 160, thresholdSeconds: thresholdSeconds
        ))
        let marks = ruler.watch.marks(in: ruler.range)

        #expect(marks.map(\.bpm) == [100, 124, 137, 148, 148])
        #expect(Set(marks.map(\.id)).count == marks.count)
    }

    @Test func timeTextListsEveryZone() {
        #expect(ZoneBar(floors: [100, 124, 137, 148, 154], seconds: watchSeconds).timeText == "Z1 1:00 · Z2 5:00 · Z3 20:00 · Z4 25:00 · Z5 2:00")
        #expect(ZoneBar(floors: [100, 124, 137, 148, 154], seconds: []).timeText == nil)
    }
}
