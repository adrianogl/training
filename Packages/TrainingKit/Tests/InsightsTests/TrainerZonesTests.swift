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
        #expect(TrainerZones.zone(TrainerStep(kind: .steady, meters: 3_000, zone: 3), in: workout(.long, steps: [])) == 3)
    }

    @Test func racePaceZoneDependsOnTheRaceDistance() {
        #expect(TrainerZones.zone(for: .goalPace, raceMeters: 21_097.5) == 4)
        #expect(TrainerZones.zone(for: .racePace, raceMeters: 21_097.5) == 4)
        #expect(TrainerZones.zone(for: .racePace, raceMeters: 42_195) == 3)
        #expect(TrainerZones.zone(for: .goalPace, raceMeters: 30_000) == 3)
        var step = TrainerStep(kind: .work, repeats: 2, meters: 5_000, method: .goalPace)
        step.zone = TrainerEngine.racePaceZone(meters: 21_097.5)
        #expect(TrainerZones.zone(step, in: workout(.vo2max, steps: [])) == 4)
    }

    @Test func bandsJoinHeartRateAndPace() {
        let bands = TrainerZones.bands(thresholdHeartRate: 172, paces: paces)

        #expect(bands.map(\.zone) == [1, 2, 3, 4, 5])
        #expect(bands[0].heartRateLow == nil && bands[0].heartRateHigh == 145)
        #expect(bands[1].heartRateLow == 146 && bands[1].heartRateHigh == 154)
        #expect(bands[3].heartRateLow == 163 && bands[3].heartRateHigh == 174)
        #expect(bands[4].heartRateLow == 175 && bands[4].heartRateHigh == nil)
        #expect(TrainerZones.bands(thresholdHeartRate: 172, paces: paces, maxHeartRate: 190)[4].heartRateHigh == 190)
        #expect(bands[0].paceLow == nil)
        #expect(bands[1].paceLow == 298 && bands[1].paceHigh == 312)
        #expect(bands[2].paceLow == 259 && bands[2].paceHigh == 265)
        #expect(bands[3].paceLow == 238 && bands[3].paceHigh == 249)
        #expect(bands[4].paceLow == 223 && bands[4].paceHigh == 229)
    }

    @Test func zonePacesAreMonotonicAndIgnoreTheGoal() {
        let real = TrainerPaces(easy: 296, long: 296, threshold: 253, vo2max: 232, race: 240)
        let bands = TrainerZones.bands(thresholdHeartRate: 165, paces: real)
        let centers = (2...5).compactMap { zone in bands[zone - 1].paceLow.flatMap { low in bands[zone - 1].paceHigh.map { (low + $0) / 2 } } }

        #expect(centers == centers.sorted(by: >))
        #expect(bands[2].paceLow == 266 && bands[2].paceHigh == 272)
        #expect(bands[3].paceLow == 245 && bands[3].paceHigh == 256)
        #expect(TrainerZones.zone(forPace: 232, paces: real) == 5)
        #expect(TrainerZones.zone(forPace: 240, paces: real) == 5)
        #expect(TrainerZones.zone(forPace: 248, paces: real) == 4)
        #expect(TrainerZones.zone(forPace: 269, paces: real) == 3)
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

    @Test func plannedStepWithHeartRateSecondTargetUsesTheBlockZone() {
        let bands = TrainerZones.bands(thresholdHeartRate: 172, paces: paces)
        let goal = PlannedStep(kind: .active, meters: 2_000, target: .pace(fastest: 226, slowest: 232), secondaryTarget: .heartRate(low: 163, high: 174))
        let noBands = TrainerZones.bands(thresholdHeartRate: nil, paces: paces)

        #expect(TrainerZones.zone(planned: goal, paces: paces, bands: bands) == 4)
        #expect(TrainerZones.zone(planned: goal, paces: paces, bands: noBands) == 5)
    }

    @Test func realPaceAveragesTimeInEachZone() {
        let easy = (0..<60).map { FITSample(t: Double($0) * 5, heartRate: 150, speed: 1_000.0 / 300) }
        let hard = (0..<60).map { FITSample(t: 300 + Double($0) * 5, heartRate: 165, speed: 1_000.0 / 245) }

        let real = TrainerZones.realPaces([easy, hard], thresholdHeartRate: 172)

        #expect(real[2].map { abs($0 - 300) < 1 } == true)
        #expect(real[4].map { abs($0 - 245) < 1 } == true)
        #expect(real[5] == nil)
    }

    private func week(_ index: Int, _ phase: TrainerPhase) -> TrainerWeek {
        TrainerWeek(
            index: index, start: Day(iso: "2026-12-07")!.adding(days: 7 * index), phase: phase, isRecovery: false, plannedMeters: 50_000,
            longMeters: 18_000, thresholdFocus: "", vo2Focus: ""
        )
    }

    @Test func halfMarathonTargetPaceWalksFromTheEquivalentToTheThreshold() {
        let real = TrainerPaces(easy: 296, long: 296, threshold: 253, vo2max: 232, race: 240)
        let weeks = [week(1, .build), week(2, .specific), week(3, .specific), week(4, .specific), week(5, .taper)]
        let half = TrainerTarget(kind: .race, name: "Meia", distanceMeters: 21_097.5, goalSeconds: 240 * 21.0975)
        let paces = weeks.map { TrainerEngine.targetPace(paces: real, target: half, week: $0, weeks: weeks).rounded() }

        #expect(paces == [258, 258, 256, 253, 253])
    }

    @Test func marathonTargetPaceIsTheGoalButNeverFasterThanTheThreshold() {
        let real = TrainerPaces(easy: 296, long: 296, threshold: 253, vo2max: 232, race: 250)
        let marathon = TrainerTarget(kind: .race, name: "Maratona", distanceMeters: 42_195)
        #expect(TrainerEngine.targetPace(paces: real, target: marathon, week: week(2, .specific), weeks: [week(2, .specific)]) == 253)
        var slower = real
        slower.race = 265
        #expect(TrainerEngine.targetPace(paces: slower, target: marathon, week: nil, weeks: []) == 265)
    }

    @Test func fractionedThresholdBlocksRunFiveSecondsFaster() {
        let real = TrainerPaces(easy: 296, long: 296, threshold: 253, vo2max: 232)
        func steps(_ meters: Double, _ method: TrainerMethod) -> [TrainerStep] {
            let session = TrainerQualitySession(
                kind: .threshold, method: method, blocks: [TrainerQualityBlock(repeats: 3, meters: meters)], closing: false
            )
            return TrainerEngine.qualitySteps(session: session, paces: real, lowered: false).filter { $0.kind == .work }
        }

        #expect(steps(2_000, .cruiseIntervals).first.map { [$0.paceLow, $0.paceHigh] } == [245, 251])
        #expect(steps(3_000, .cruiseIntervals).first.map { [$0.paceLow, $0.paceHigh] } == [250, 256])
        #expect(steps(5_000, .tempo).first.map { [$0.paceLow, $0.paceHigh] } == [250, 256])
    }
}
