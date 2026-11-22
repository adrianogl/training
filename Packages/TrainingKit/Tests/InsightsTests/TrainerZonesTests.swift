import FITReader
import Foundation
import GarminAPI
import Testing
import TrainingCore
@testable import Insights

@Suite struct TrainerZonesTests {
    private let paces = TrainerPaces(easy: 305, long: 300, threshold: 246, vo2max: 226, race: 265)

    private func workout(_ kind: TrainerDayKind, steps: [TrainerStep]) -> TrainerWorkout {
        TrainerWorkout(day: Day(iso: "2026-12-01")!, kind: kind, title: "", totalMeters: 12_000, steps: steps, rationale: "")
    }

    @Test func zoneFollowsTheBlockKind() {
        let warmup = TrainerStep(kind: .warmup, repeats: 1, meters: 4_000)
        let threshold = TrainerStep(kind: .work, repeats: 4, meters: 2_000, restSeconds: 120, paceLow: 243, paceHigh: 249)
        let vo2 = TrainerStep(kind: .work, repeats: 5, meters: 1_000, restSeconds: 150, paceLow: 224, paceHigh: 228)
        var race = TrainerStep(kind: .work, repeats: 3, meters: 3_000)
        race.method = .racePace
        let trot = TrainerStep(kind: .recovery, repeats: 3, meters: 400)

        #expect(TrainerZones.zone(warmup, in: workout(.threshold, steps: [])) == 2)
        #expect(TrainerZones.zone(threshold, in: workout(.threshold, steps: [])) == 4)
        #expect(TrainerZones.zone(vo2, in: workout(.vo2max, steps: [])) == 5)
        #expect(TrainerZones.zone(race, in: workout(.threshold, steps: [])) == 3)
        #expect(TrainerZones.zone(trot, in: workout(.vo2max, steps: [])) == nil)
        #expect(TrainerZones.zone(TrainerStep(kind: .steady, repeats: 1, meters: 18_000), in: workout(.long, steps: [])) == 2)
    }

    @Test func heartRateTargetSkipsShortAndFastBlocks() {
        let limiar = TrainerStep(kind: .work, repeats: 4, meters: 2_000, paceLow: 243, paceHigh: 249)
        let short = TrainerStep(kind: .work, repeats: 6, meters: 1_000, paceLow: 243, paceHigh: 249)
        let vo2 = TrainerStep(kind: .work, repeats: 5, meters: 1_000)

        #expect(TrainerZones.usesHeartRateTarget(limiar, in: workout(.threshold, steps: [])))
        #expect(!TrainerZones.usesHeartRateTarget(short, in: workout(.threshold, steps: [])))
        #expect(!TrainerZones.usesHeartRateTarget(vo2, in: workout(.vo2max, steps: [])))
        #expect(TrainerZones.usesHeartRateTarget(TrainerStep(kind: .warmup, repeats: 1, meters: 3_000), in: workout(.vo2max, steps: [])))
    }

    @Test func bandsJoinHeartRateAndPace() {
        let bands = TrainerZones.bands(thresholdHeartRate: 172, paces: paces)

        #expect(bands.map(\.zone) == [1, 2, 3, 4, 5])
        #expect(bands[0].heartRateLow == nil && bands[0].heartRateHigh == 145)
        #expect(bands[1].heartRateLow == 146 && bands[1].heartRateHigh == 154)
        #expect(bands[4].heartRateLow == 172 && bands[4].heartRateHigh == nil)
        #expect(bands[0].paceLow == nil)
        #expect(bands[1].paceLow == 298 && bands[1].paceHigh == 312)
        #expect(bands[3].paceLow == 243 && bands[3].paceHigh == 249)
    }

    @Test func plannedStepZoneComesFromItsTarget() {
        let bands = TrainerZones.bands(thresholdHeartRate: 172, paces: paces)
        let pace = PlannedStep(kind: .active, meters: 2_000, target: .pace(fastest: 243, slowest: 249))
        let easy = PlannedStep(kind: .active, meters: 10_000, target: .pace(fastest: 300, slowest: 315))
        let heart = PlannedStep(kind: .active, meters: 5_000, target: .heartRate(low: 160, high: 168))

        #expect(TrainerZones.zone(planned: pace, paces: paces, bands: bands) == 4)
        #expect(TrainerZones.zone(planned: easy, paces: paces, bands: bands) == 2)
        #expect(TrainerZones.zone(planned: heart, paces: paces, bands: bands) == 4)
        #expect(TrainerZones.zone(planned: PlannedStep(kind: .rest, seconds: 120), paces: paces, bands: bands) == nil)
    }

    @Test func realPaceAveragesTimeInEachZone() {
        let easy = (0..<60).map { FITSample(t: Double($0) * 5, heartRate: 150, speed: 1_000.0 / 300) }
        let hard = (0..<60).map { FITSample(t: 300 + Double($0) * 5, heartRate: 165, speed: 1_000.0 / 245) }

        let real = TrainerZones.realPaces([easy, hard], thresholdHeartRate: 172)

        #expect(real[2].map { abs($0 - 300) < 1 } == true)
        #expect(real[4].map { abs($0 - 245) < 1 } == true)
        #expect(real[5] == nil)
    }
}
