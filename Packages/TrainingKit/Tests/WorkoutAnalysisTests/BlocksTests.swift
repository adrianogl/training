import FITReader
import Testing
@testable import WorkoutAnalysis

private func laps(_ plan: [(step: Int?, intensity: StepIntensity?, count: Int, seconds: Double, meters: Double)], heartRate: Int? = 150) -> [LapSummary] {
    var offset = 0.0
    var result: [LapSummary] = []
    for block in plan {
        for _ in 0..<block.count {
            result.append(LapSummary(
                stepIndex: block.step,
                intensity: block.intensity,
                trigger: "distance",
                startOffset: offset,
                timerSeconds: block.seconds,
                distance: block.meters,
                avgSpeed: block.meters / block.seconds,
                avgHeartRate: heartRate,
                maxHeartRate: heartRate.map { $0 + 15 }
            ))
            offset += block.seconds
        }
    }
    return result
}

private func singleStep(target: StepTarget, seconds: Double, meters: Double, heartRate: Int? = nil) -> WorkoutStructure {
    WorkoutStructure(
        prescription: WorkoutPrescription(steps: [PrescribedStep(index: 0, intensity: .active, duration: .open, target: target)]),
        laps: laps([(0, .active, 1, seconds, meters)], heartRate: heartRate)
    )
}

private let zones = HeartRateZones(floors: [100, 120, 140, 160, 175], maxHeartRate: 190)

@Test func groupsLapsByStep() {
    let prescription = WorkoutPrescription(name: "Fartlek sintético", steps: [
        PrescribedStep(index: 0, intensity: .warmup, duration: .distance(meters: 3000), target: .speed(low: 3.0, high: 3.2)),
        PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 7000), target: .speed(low: 3.9, high: 4.15)),
        PrescribedStep(index: 2, intensity: .recovery, duration: .time(seconds: 240), target: .open),
        PrescribedStep(index: 3, intensity: .active, duration: .distance(meters: 3000), target: .speed(low: 3.9, high: 4.15)),
    ])
    var executed = laps([
        (0, .warmup, 3, 320, 1000),
        (1, .active, 7, 250, 1000),
        (2, .recovery, 1, 240, 500),
        (3, .active, 1, 250, 1000),
    ])
    executed.append(LapSummary(trigger: "session_end", startOffset: 4130, timerSeconds: 2, distance: 4))

    let blocks = buildBlocks(WorkoutStructure(prescription: prescription, laps: executed), zones: nil)

    #expect(blocks.map(\.kind) == [.warmup, .active, .recovery, .active])
    #expect(blocks.map(\.label) == ["Aquecimento", "Bloco 1", "Recuperação 1", "Bloco 2"])
    #expect(blocks[1].laps.count == 7)
    #expect(blocks[1].distance == 7000)
    #expect(blocks[1].seconds == 1750)
    #expect(blocks[1].prescribed?.index == 1)
    #expect(blocks.map(\.status) == [.inTarget, .inTarget, .noTarget, .incomplete])
    #expect(blocks.allSatisfy { $0.dominantZone == nil })
    #expect(hasPrescription(WorkoutStructure(prescription: prescription, laps: executed)))
}

@Test func unrollsRepeats() {
    let prescription = WorkoutPrescription(steps: [
        PrescribedStep(index: 0, intensity: .warmup, duration: .time(seconds: 600), target: .open),
        PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 800), target: .speed(low: 4.4, high: 4.7)),
        PrescribedStep(index: 2, intensity: .recovery, duration: .time(seconds: 120), target: .open),
        PrescribedStep(index: 3, intensity: .active, duration: .repeatSteps(fromIndex: 1, count: 6), target: .open),
        PrescribedStep(index: 4, intensity: .cooldown, duration: .time(seconds: 600), target: .open),
    ])
    var plan: [(step: Int?, intensity: StepIntensity?, count: Int, seconds: Double, meters: Double)] = [(0, .warmup, 1, 600, 1800)]
    for _ in 0..<6 {
        plan.append((1, .active, 1, 176, 800))
        plan.append((2, .recovery, 1, 120, 250))
    }
    plan.append((4, .cooldown, 1, 600, 1700))

    let blocks = buildBlocks(WorkoutStructure(prescription: prescription, laps: laps(plan)), zones: nil)

    #expect(blocks.count == 14)
    #expect(blocks.first?.label == "Aquecimento")
    #expect(blocks.last?.label == "Desaquecimento")
    #expect(blocks.filter { $0.kind == .active }.map(\.label) == (1...6).map { "Tiro \($0)" })
    #expect(blocks.filter { $0.kind == .recovery }.map(\.label) == (1...6).map { "Recuperação \($0)" })
    #expect(blocks.filter { $0.kind == .active }.map(\.ordinal) == Array(1...6))
    #expect(blocks.allSatisfy { $0.prescribed?.index != 3 })
    #expect(blocks.filter { $0.kind == .active }.allSatisfy { $0.status == .inTarget && $0.laps.count == 1 })
}

@Test func statusAgainstPaceTarget() {
    let target = StepTarget.speed(low: 3.9, high: 4.15)
    func status(seconds: Double, meters: Double) -> BlockStatus? {
        buildBlocks(singleStep(target: target, seconds: seconds, meters: meters), zones: nil).first?.status
    }
    #expect(status(seconds: 250, meters: 1000) == .inTarget)
    #expect(status(seconds: 1000, meters: 4300) == .faster)
    #expect(status(seconds: 1000, meters: 3700) == .slower)
    #expect(status(seconds: 1000, meters: 3900) == .inTarget)
    #expect(status(seconds: 1000, meters: 4150) == .inTarget)

    let block = buildBlocks(singleStep(target: target, seconds: 250, meters: 1000), zones: nil)[0]
    #expect(block.avgSpeed == 4.0)
}

@Test func blockSpeedIsDistanceOverTime() {
    let prescription = WorkoutPrescription(steps: [
        PrescribedStep(index: 0, intensity: .active, duration: .open, target: .speed(low: 3.9, high: 4.15)),
    ])
    let executed = laps([(0, .active, 1, 200, 1000), (0, .active, 1, 300, 1000)])
    let block = buildBlocks(WorkoutStructure(prescription: prescription, laps: executed), zones: nil)[0]
    #expect(block.seconds == 500)
    #expect(block.distance == 2000)
    #expect(block.avgSpeed == 4.0)
    #expect(block.status == .inTarget)
}

@Test func statusAgainstHeartRateZone() {
    func block(_ target: StepTarget, heartRate: Int, zones: HeartRateZones?) -> WorkoutBlock {
        buildBlocks(singleStep(target: target, seconds: 600, meters: 2000, heartRate: heartRate), zones: zones)[0]
    }
    #expect(block(.heartRateZone(2), heartRate: 130, zones: zones).status == .inTarget)
    #expect(block(.heartRateZone(2), heartRate: 150, zones: zones).status == .aboveTarget)
    #expect(block(.heartRateZone(2), heartRate: 110, zones: zones).status == .belowTarget)
    #expect(block(.heartRateZone(2), heartRate: 120, zones: zones).status == .inTarget)
    #expect(block(.heartRateZone(2), heartRate: 139, zones: zones).status == .inTarget)
    #expect(block(.heartRateZone(2), heartRate: 140, zones: zones).status == .aboveTarget)
    #expect(block(.heartRateZone(5), heartRate: 210, zones: zones).status == .inTarget)
    #expect(block(.heartRateZone(2), heartRate: 130, zones: nil).status == .noTarget)
}

@Test func statusAgainstHeartRateBpmAndPercentMax() {
    func block(_ target: StepTarget, heartRate: Int, zones: HeartRateZones?) -> WorkoutBlock {
        buildBlocks(singleStep(target: target, seconds: 600, meters: 2000, heartRate: heartRate), zones: zones)[0]
    }
    #expect(block(.heartRateBpm(low: 145, high: 160), heartRate: 145, zones: nil).status == .inTarget)
    #expect(block(.heartRateBpm(low: 145, high: 160), heartRate: 160, zones: nil).status == .inTarget)
    #expect(block(.heartRateBpm(low: 145, high: 160), heartRate: 161, zones: nil).status == .aboveTarget)
    #expect(block(.heartRateBpm(low: 145, high: 160), heartRate: 144, zones: nil).status == .belowTarget)
    #expect(block(.heartRatePercentMax(low: 70, high: 80), heartRate: 140, zones: zones).status == .inTarget)
    #expect(block(.heartRatePercentMax(low: 70, high: 80), heartRate: 160, zones: zones).status == .aboveTarget)
    #expect(block(.heartRatePercentMax(low: 70, high: 80), heartRate: 120, zones: zones).status == .belowTarget)
    #expect(block(.heartRatePercentMax(low: 70, high: 80), heartRate: 140, zones: HeartRateZones(floors: zones.floors)).status == .noTarget)
}

@Test func heartRateIsTimeWeightedAndGivesDominantZone() {
    let prescription = WorkoutPrescription(steps: [
        PrescribedStep(index: 0, intensity: .active, duration: .open, target: .open),
    ])
    let executed = [
        LapSummary(stepIndex: 0, startOffset: 0, timerSeconds: 300, distance: 1000, avgHeartRate: 130, maxHeartRate: 140),
        LapSummary(stepIndex: 0, startOffset: 300, timerSeconds: 100, distance: 400, avgHeartRate: 170, maxHeartRate: 178),
    ]
    let structure = WorkoutStructure(prescription: prescription, laps: executed)
    let block = buildBlocks(structure, zones: zones)[0]
    #expect(block.avgHeartRate == 140)
    #expect(block.maxHeartRate == 178)
    #expect(block.dominantZone == 3)
    #expect(block.status == .noTarget)
    #expect(buildBlocks(structure, zones: nil)[0].dominantZone == nil)
}

@Test func incompleteAndNotExecuted() {
    let prescription = WorkoutPrescription(steps: [
        PrescribedStep(index: 0, intensity: .warmup, duration: .distance(meters: 1000), target: .open),
        PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 2000), target: .speed(low: 3.9, high: 4.15)),
        PrescribedStep(index: 2, intensity: .recovery, duration: .time(seconds: 120), target: .open),
        PrescribedStep(index: 3, intensity: .cooldown, duration: .distance(meters: 1000), target: .open),
    ])
    let executed = laps([(0, .warmup, 1, 320, 1000), (1, .active, 1, 300, 1200)])

    let blocks = buildBlocks(WorkoutStructure(prescription: prescription, laps: executed), zones: nil)

    #expect(blocks.count == 4)
    #expect(blocks[0].status == .noTarget)
    #expect(blocks[1].status == .incomplete)
    #expect(blocks[2].status == .notExecuted && blocks[2].laps == [])
    #expect(blocks[3].status == .notExecuted && blocks[3].laps == [])
    #expect(blocks.map(\.label) == ["Aquecimento", "Bloco 1", "Recuperação 1", "Desaquecimento"])
}

@Test func completionThresholdIsNinetyFivePercent() {
    let prescription = WorkoutPrescription(steps: [
        PrescribedStep(index: 0, intensity: .active, duration: .distance(meters: 1000), target: .open),
        PrescribedStep(index: 1, intensity: .recovery, duration: .time(seconds: 100), target: .open),
    ])
    let complete = laps([(0, .active, 1, 240, 950), (1, .recovery, 1, 95, 200)])
    let short = laps([(0, .active, 1, 240, 949), (1, .recovery, 1, 94, 200)])
    #expect(buildBlocks(WorkoutStructure(prescription: prescription, laps: complete), zones: nil).map(\.status) == [.noTarget, .noTarget])
    #expect(buildBlocks(WorkoutStructure(prescription: prescription, laps: short), zones: nil).map(\.status) == [.incomplete, .incomplete])
}

@Test func dropsSessionEndLap() {
    let prescription = WorkoutPrescription(steps: [
        PrescribedStep(index: 0, intensity: .active, duration: .distance(meters: 2000), target: .open),
    ])
    var executed = laps([(0, .active, 2, 250, 1000)])
    executed.append(LapSummary(trigger: "session_end", startOffset: 500, timerSeconds: 2, distance: 4))
    let blocks = buildBlocks(WorkoutStructure(prescription: prescription, laps: executed), zones: nil)
    #expect(blocks.count == 1)
    #expect(blocks[0].laps.count == 2)
    #expect(blocks[0].distance == 2000)

    var short = laps([(0, .active, 2, 250, 1000)])
    short.append(LapSummary(trigger: "manual", startOffset: 500, timerSeconds: 6, distance: 15))
    let shortBlocks = buildBlocks(WorkoutStructure(prescription: prescription, laps: short), zones: nil)
    #expect(shortBlocks.count == 1)
    #expect(shortBlocks[0].distance == 2000)
}

@Test func freeRunUsesLaps() {
    let structure = WorkoutStructure(prescription: nil, laps: laps([(nil, nil, 5, 300, 1000)]))
    let blocks = buildBlocks(structure, zones: zones)
    #expect(blocks.count == 5)
    #expect(blocks.allSatisfy { $0.kind == .active && $0.status == .noTarget && $0.laps.count == 1 })
    #expect(blocks.map(\.label) == (1...5).map { "Volta \($0)" })
    #expect(blocks.map(\.ordinal) == Array(1...5))
    #expect(blocks[0].dominantZone == 3)
    #expect(hasPrescription(structure) == false)
}

@Test func skippedStepBecomesNotExecuted() {
    let prescription = WorkoutPrescription(steps: [
        PrescribedStep(index: 0, intensity: .warmup, duration: .open, target: .open),
        PrescribedStep(index: 1, intensity: .active, duration: .open, target: .open),
        PrescribedStep(index: 2, intensity: .rest, duration: .open, target: .open),
    ])
    let executed = laps([(0, .warmup, 1, 300, 1000), (2, .rest, 1, 120, 300)])
    let blocks = buildBlocks(WorkoutStructure(prescription: prescription, laps: executed), zones: nil)
    #expect(blocks.map(\.status) == [.noTarget, .notExecuted, .noTarget])
    #expect(blocks.map(\.label) == ["Aquecimento", "Bloco 1", "Recuperação 1"])
    #expect(blocks[2].kind == .recovery)
}
