import FITReader
import Foundation
import Storage
import Testing
@testable import WorkoutAnalysis

private struct Segment: Sendable {
    let intensity: StepIntensity
    let seconds: Double
    let meters: Double
    let heartRate: @Sendable (Double) -> Int
}

private func record(name: String, segments: [Segment]) throws -> ActivityRecord {
    var steps: [PrescribedStep] = []
    var laps: [LapSummary] = []
    var offset = 0.0
    for (index, segment) in segments.enumerated() {
        let duration: StepDuration = segment.meters > 0 ? .distance(meters: segment.meters) : .time(seconds: segment.seconds)
        let target: StepTarget = segment.intensity == .active ? .speed(low: 3.2, high: 3.5) : .open
        steps.append(PrescribedStep(index: index, intensity: segment.intensity, duration: duration, target: target))
        laps.append(LapSummary(
            stepIndex: index, intensity: segment.intensity, trigger: "distance", startOffset: offset,
            timerSeconds: segment.seconds, distance: segment.meters, avgSpeed: segment.meters > 0 ? segment.meters / segment.seconds : nil
        ))
        offset += segment.seconds
    }
    let structure = WorkoutStructure(prescription: WorkoutPrescription(name: name, steps: steps), laps: laps)
    return ActivityRecord(
        activityId: 1, typeKey: "running", name: name, distance: segments.reduce(0) { $0 + $1.meters },
        structureData: try JSONEncoder().encode(structure)
    )
}

private func samples(_ segments: [Segment], stall: ClosedRange<Double>? = nil) -> [FITSample] {
    var result: [FITSample] = []
    var start = 0.0
    var distance = 0.0
    for segment in segments {
        let speed = segment.meters / segment.seconds
        for second in 0..<Int(segment.seconds) {
            let t = start + Double(second)
            if stall?.contains(t) != true { distance += speed }
            result.append(FITSample(t: t, heartRate: segment.heartRate(Double(second)), distance: distance))
        }
        start += segment.seconds
    }
    return result
}

private let warmup = Segment(intensity: .warmup, seconds: 900, meters: 3_000) { _ in 140 }
private let rest = Segment(intensity: .rest, seconds: 60, meters: 0) { _ in 130 }

private func fractioned(rest: Segment = rest) -> [Segment] {
    let blocks = (0..<4).map { index in
        Segment(intensity: .active, seconds: 300, meters: 1_000) { second in second < 60 ? 150 : 160 + index }
    }
    return [warmup, blocks[0], rest, blocks[1], rest, blocks[2], rest, blocks[3]]
}

private let continuous = [warmup, Segment(intensity: .active, seconds: 1_200, meters: 4_000) { second in second < 600 ? 160 : 168 }]

@Suite struct ThresholdEstimateTests {
    @Test func fractionedUsesTheLastThreeBlocksWithoutTheirFirstMinute() throws {
        let segments = fractioned()

        let estimate = estimateThresholdHeartRate(
            try record(name: "Limiar 4 × 1 km", segments: segments), samples: samples(segments), heatFactor: nil, raceGoalKms: []
        )

        #expect(estimate == 162)
    }

    @Test func continuousUsesTheSecondHalfOfTheBlock() throws {
        let estimate = estimateThresholdHeartRate(
            try record(name: "Limiar 4 km", segments: continuous), samples: samples(continuous), heatFactor: 0.03, raceGoalKms: []
        )

        #expect(estimate == 168)
    }

    @Test func strongHeatDiscardsTheRun() throws {
        let estimate = estimateThresholdHeartRate(
            try record(name: "Limiar 4 km", segments: continuous), samples: samples(continuous), heatFactor: 0.045, raceGoalKms: []
        )

        #expect(estimate == nil)
    }

    @Test func discardRuleStartsAtStrongHeat() {
        #expect(!discardsThresholdEstimate(heatFactor: nil))
        #expect(!discardsThresholdEstimate(heatFactor: 0.044))
        #expect(discardsThresholdEstimate(heatFactor: 0.045))
    }

    @Test func pauseLongerThanThirtySecondsInsideTheBlockDiscardsTheRun() throws {
        let run = try record(name: "Limiar 4 km", segments: continuous)

        #expect(estimateThresholdHeartRate(run, samples: samples(continuous, stall: 1_400...1_440), heatFactor: nil, raceGoalKms: []) == nil)
        #expect(estimateThresholdHeartRate(run, samples: samples(continuous, stall: 1_400...1_420), heatFactor: nil, raceGoalKms: []) == 168)
    }

    @Test func shortContinuousBlockAndLongRestsGiveNoEstimate() throws {
        let short = [warmup, Segment(intensity: .active, seconds: 720, meters: 2_400) { _ in 166 }]
        let longRest = fractioned(rest: Segment(intensity: .rest, seconds: 120, meters: 0) { _ in 130 })

        #expect(estimateThresholdHeartRate(try record(name: "Limiar", segments: short), samples: samples(short), heatFactor: nil, raceGoalKms: []) == nil)
        #expect(estimateThresholdHeartRate(try record(name: "Limiar", segments: longRest), samples: samples(longRest), heatFactor: nil, raceGoalKms: []) == nil)
    }

    @Test func runThatIsNotThresholdGivesNoEstimate() throws {
        let estimate = estimateThresholdHeartRate(
            try record(name: "Rodagem", segments: [warmup]), samples: samples([warmup]), heatFactor: nil, raceGoalKms: []
        )

        #expect(estimate == nil)
    }

    @Test func maxHeartRateIgnoresSpikesShorterThanFiveSeconds() {
        var points = (0..<120).map { FITSample(t: Double($0), heartRate: 170) }
        for second in 20..<24 { points[second].heartRate = 205 }
        for second in 60..<66 { points[second].heartRate = 187 }

        #expect(sustainedMaxHeartRate(points) == 187)
    }

    @Test func maxHeartRateNeedsContinuousSamples() {
        let points = [FITSample(t: 0, heartRate: 190), FITSample(t: 30, heartRate: 190), FITSample(t: 31, heartRate: 160)]

        #expect(sustainedMaxHeartRate(points) == nil)
    }
}
