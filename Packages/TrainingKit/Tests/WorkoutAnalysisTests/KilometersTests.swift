import TrainingCore
import FITReader
import Testing
@testable import WorkoutAnalysis

private struct Segment {
    var seconds: Double
    var meters: Double
    var heartRate: Int = 150
}

private func kilometers(_ paces: [Double], heartRates: [Int]? = nil) -> [Segment] {
    paces.enumerated().map { index, pace in
        Segment(seconds: pace, meters: 1_000, heartRate: heartRates?[index] ?? 150)
    }
}

private func track(_ segments: [Segment], step: Double = 5) -> [FITSample] {
    var samples: [FITSample] = []
    var startTime = 0.0
    var startDistance = 0.0
    for (index, segment) in segments.enumerated() {
        let isLast = index == segments.count - 1
        let times = Array(stride(from: 0.0, to: segment.seconds, by: step)) + (isLast ? [segment.seconds] : [])
        for offset in times {
            samples.append(FITSample(
                t: startTime + offset,
                heartRate: segment.heartRate,
                speed: segment.meters / segment.seconds,
                distance: startDistance + segment.meters * offset / segment.seconds
            ))
        }
        startTime += segment.seconds
        startDistance += segment.meters
    }
    return samples
}

private func lap(step: Int, intensity: StepIntensity, start: Double, segments: [Segment]) -> LapSummary {
    let seconds = segments.reduce(0) { $0 + $1.seconds }
    let meters = segments.reduce(0) { $0 + $1.meters }
    return LapSummary(
        stepIndex: step,
        intensity: intensity,
        trigger: "distance",
        startOffset: start,
        timerSeconds: seconds,
        distance: meters,
        avgSpeed: meters / seconds,
        avgHeartRate: segments.first?.heartRate
    )
}

private func continuous(_ segments: [Segment], target: StepTarget, duration: StepDuration = .open) -> (WorkoutStructure, [FITSample]) {
    let structure = WorkoutStructure(
        prescription: WorkoutPrescription(steps: [PrescribedStep(index: 0, intensity: .active, duration: duration, target: target)]),
        laps: [lap(step: 0, intensity: .active, start: 0, segments: segments)]
    )
    return (structure, track(segments))
}

private let zones = HeartRateZones(floors: [100, 120, 140, 160, 175], maxHeartRate: 190)

@Test func largeBlockSplitsIntoKilometers() {
    let (structure, samples) = continuous(kilometers(Array(repeating: 300, count: 5)), target: .speed(low: 1_000 / 305, high: 1_000 / 295), duration: .distance(meters: 5_000))
    let blocks = buildBlocks(structure, zones: zones)

    let split = kilometerSplits(of: blocks, samples: samples, zones: zones)

    let rows = try! #require(split[0])
    #expect(rows.map(\.label) == ["Km 1", "Km 2", "Km 3", "Km 4", "Km 5"])
    #expect(rows.allSatisfy { abs($0.distance - 1_000) < 1 && abs($0.seconds - 300) < 1 })
    #expect(rows.allSatisfy { $0.status == .inTarget && $0.kind == .active && $0.laps.count == 1 })
    #expect(rows.allSatisfy { $0.prescribed == blocks[0].prescribed })
    #expect(rows[0].dominantZone == 3)
    #expect(blocks[0].status == .inTarget)
}

@Test func longDurationBlockSplitsEvenUnder3Km() {
    let (structure, samples) = continuous([Segment(seconds: 960, meters: 2_800)], target: .open, duration: .time(seconds: 960))
    let blocks = buildBlocks(structure, zones: nil)

    let rows = try! #require(kilometerSplits(of: blocks, samples: samples, zones: nil)[0])

    #expect(rows.map(\.label) == ["Km 1", "Km 2", "Km 3"])
    #expect(rows[0].distance >= 1_000 && rows[0].distance < 1_020)
    #expect(abs(rows[2].distance - 800) < 30)
    #expect(rows.allSatisfy { $0.status == .noTarget })
}

@Test func shortBlocksStayWhole() {
    let prescription = WorkoutPrescription(steps: [
        PrescribedStep(index: 0, intensity: .active, duration: .distance(meters: 1_000), target: .speed(low: 4.0, high: 4.4)),
        PrescribedStep(index: 1, intensity: .recovery, duration: .time(seconds: 120), target: .open),
        PrescribedStep(index: 2, intensity: .active, duration: .repeatSteps(fromIndex: 0, count: 5), target: .open),
    ])
    var segments: [Segment] = []
    var laps: [LapSummary] = []
    var offset = 0.0
    for _ in 0..<5 {
        let fast = Segment(seconds: 240, meters: 1_000, heartRate: 165)
        let easy = Segment(seconds: 120, meters: 300, heartRate: 130)
        laps.append(lap(step: 0, intensity: .active, start: offset, segments: [fast]))
        laps.append(lap(step: 1, intensity: .recovery, start: offset + 240, segments: [easy]))
        segments += [fast, easy]
        offset += 360
    }
    let blocks = buildBlocks(WorkoutStructure(prescription: prescription, laps: laps), zones: zones)

    let split = kilometerSplits(of: blocks, samples: track(segments), zones: zones)

    #expect(blocks.count == 10)
    #expect(split.isEmpty)
}

@Test func kmStatusUsesBlockTarget() {
    let (paceStructure, paceSamples) = continuous(kilometers([300, 300, 320, 280]), target: .speed(low: 1_000 / 305, high: 1_000 / 295))
    let paceBlocks = buildBlocks(paceStructure, zones: zones)
    let paceRows = try! #require(kilometerSplits(of: paceBlocks, samples: paceSamples, zones: zones)[0])
    #expect(paceRows.map(\.status) == [.inTarget, .inTarget, .slower, .faster])

    let (zoneStructure, zoneSamples) = continuous(kilometers([300, 300, 300, 300], heartRates: [150, 165, 130, 150]), target: .heartRateZone(3))
    let zoneBlocks = buildBlocks(zoneStructure, zones: zones)
    let zoneRows = try! #require(kilometerSplits(of: zoneBlocks, samples: zoneSamples, zones: zones)[0])
    #expect(zoneRows.map(\.status) == [.inTarget, .aboveTarget, .belowTarget, .inTarget])
}

@Test func singleLapBlockGetsPaceFadeFromKilometers() {
    let (structure, samples) = continuous(kilometers([300, 300, 300, 300, 300, 300, 315, 315]), target: .open)
    let blocks = buildBlocks(structure, zones: nil)
    let split = kilometerSplits(of: blocks, samples: samples, zones: nil)

    let withKilometers = assess(blocks, context: AssessmentContext(kilometers: split))
    let lapsOnly = assess(blocks, context: AssessmentContext())

    let fade = try! #require(withKilometers.negatives.first { $0.kind == .paceFade })
    #expect(fade.blockOrdinal == 0)
    #expect(abs((fade.facts[FindingFact.fade] ?? 0) - 15) < 1)
    #expect(!lapsOnly.negatives.contains { $0.kind == .paceFade })
}

@Test func freeRunUnchanged() {
    let samples = track([Segment(seconds: 750, meters: 2_500, heartRate: 150)])

    let rows = kilometerSplits(samples, zones: zones)

    #expect(rows.map(\.label) == ["Km 1", "Km 2", "Km 3"])
    #expect(abs(rows[0].seconds - 300) < 1)
    #expect(abs(rows[0].distance - 1_000) < 1)
    #expect(abs(rows[2].distance - 500) < 20)
    #expect(rows.allSatisfy { $0.status == .noTarget && $0.kind == .active && $0.laps.count == 1 && $0.prescribed == nil })
    #expect(rows[0].dominantZone == 3)
    #expect(kilometerSplits([], zones: nil).isEmpty)
    #expect(kilometerSplits(track([Segment(seconds: 606, meters: 2_020)]), zones: nil).count == 2)
}

@Test func kilometerTimeSkipsPauses() {
    let (structure, running) = continuous(kilometers([300, 300, 300]), target: .speed(low: 1_000 / 305, high: 1_000 / 295))
    let pause = 120.0
    let samples = running.map { sample in
        var shifted = sample
        if sample.t > 450 { shifted.t += pause }
        return shifted
    }
    var laps = structure.laps
    laps[0].timerSeconds = 900
    let blocks = buildBlocks(WorkoutStructure(prescription: structure.prescription, laps: laps), zones: zones)

    let rows = try! #require(kilometerSplits(of: blocks, samples: samples, zones: zones)[0])

    #expect(rows.count == 3)
    #expect(rows.allSatisfy { abs($0.seconds - 300) < 6 })
    #expect(rows.map(\.status) == [.inTarget, .inTarget, .inTarget])
    #expect(kilometerSplits(samples, zones: nil).allSatisfy { abs($0.seconds - 300) < 6 })
}

@Test func longGapWithDistanceAdvancingKeepsTime() {
    let (structure, continuousSamples) = continuous(kilometers([300, 300, 300]), target: .speed(low: 1_000 / 305, high: 1_000 / 295))
    let gapped = continuousSamples.filter { $0.t <= 400 || $0.t >= 420 }
    let blocks = buildBlocks(structure, zones: zones)

    let rows = try! #require(kilometerSplits(of: blocks, samples: gapped, zones: zones)[0])
    let reference = try! #require(kilometerSplits(of: blocks, samples: continuousSamples, zones: zones)[0])

    #expect(rows.map(\.seconds) == reference.map(\.seconds))
    #expect(rows.map(\.status) == [.inTarget, .inTarget, .inTarget])
    #expect(kilometerSplits(gapped, zones: nil).map(\.seconds) == kilometerSplits(continuousSamples, zones: nil).map(\.seconds))
}

@Test func blocksAreChronologicalForKilometerWindow() {
    let prescription = WorkoutPrescription(steps: [
        PrescribedStep(index: 0, intensity: .warmup, duration: .time(seconds: 900), target: .open),
        PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 1_000), target: .speed(low: 4.0, high: 4.4)),
        PrescribedStep(index: 2, intensity: .recovery, duration: .time(seconds: 120), target: .open),
        PrescribedStep(index: 3, intensity: .active, duration: .repeatSteps(fromIndex: 1, count: 3), target: .open),
        PrescribedStep(index: 4, intensity: .active, duration: .distance(meters: 5_000), target: .open),
        PrescribedStep(index: 5, intensity: .cooldown, duration: .time(seconds: 600), target: .open),
    ])
    var laps: [LapSummary] = []
    var offset = 0.0
    func add(_ step: Int, _ intensity: StepIntensity, _ segments: [Segment]) {
        laps.append(lap(step: step, intensity: intensity, start: offset, segments: segments))
        offset += segments.reduce(0) { $0 + $1.seconds } + 30
    }
    add(0, .warmup, [Segment(seconds: 900, meters: 2_700)])
    add(1, .active, [Segment(seconds: 240, meters: 1_000)])
    add(2, .recovery, [Segment(seconds: 120, meters: 300)])
    add(1, .active, [Segment(seconds: 240, meters: 1_000)])
    for _ in 0..<5 { add(4, .active, kilometers([300])) }
    add(5, .cooldown, [Segment(seconds: 600, meters: 1_800)])

    let blocks = buildBlocks(WorkoutStructure(prescription: prescription, laps: laps), zones: nil)
    let executed = blocks.filter { !$0.laps.isEmpty }

    #expect(executed.flatMap(\.laps) == laps)
    for (current, next) in zip(executed, executed.dropFirst()) {
        let lastLap = try! #require(current.laps.last)
        let nextStart = try! #require(next.laps.first?.startOffset)
        #expect(lastLap.startOffset + lastLap.timerSeconds <= nextStart)
    }
    #expect(blocks.contains { $0.laps.isEmpty && $0.status == .notExecuted })
}
