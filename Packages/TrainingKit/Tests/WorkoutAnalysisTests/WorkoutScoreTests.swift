import FITReader
import Testing
import TrainingCore
@testable import WorkoutAnalysis

private let zones = HeartRateZones(floors: [100, 120, 140, 160, 175], maxHeartRate: 190)

private func block(
    _ kind: BlockKind,
    step: PrescribedStep?,
    status: BlockStatus,
    seconds: Double = 200,
    distance: Double = 800,
    heartRate: Int? = 170
) -> WorkoutBlock {
    WorkoutBlock(
        kind: kind,
        ordinal: 1,
        label: "b",
        prescribed: step,
        laps: [],
        seconds: seconds,
        distance: distance,
        avgSpeed: seconds > 0 ? distance / seconds : nil,
        avgHeartRate: heartRate,
        maxHeartRate: nil,
        dominantZone: nil,
        status: status
    )
}

private let sprintStep = PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 800), target: .speed(low: 3.8, high: 4.2))
private let warmupStep = PrescribedStep(index: 0, intensity: .warmup, duration: .time(seconds: 600), target: .open)
private let recoveryStep = PrescribedStep(index: 2, intensity: .recovery, duration: .time(seconds: 120), target: .open)

private func intervalBlocks(sprintHeartRate: Int = 170, recoveryHeartRate: Int = 150) -> [WorkoutBlock] {
    var result = [block(.warmup, step: warmupStep, status: .noTarget, seconds: 600, distance: 1800, heartRate: 130)]
    for _ in 0..<6 {
        result.append(block(.active, step: sprintStep, status: .inTarget, heartRate: sprintHeartRate))
        result.append(block(.recovery, step: recoveryStep, status: .noTarget, seconds: 120, distance: 250, heartRate: recoveryHeartRate))
    }
    return result
}

private func occurrences(_ blocks: [WorkoutBlock], count: Int) -> [WorkoutOccurrence] {
    (0..<count).map { WorkoutOccurrence(activityId: Int64($0), day: Day(year: 2026, month: 1, day: $0 + 1), blocks: blocks) }
}

private func item(_ score: WorkoutScore?, _ part: ScorePart) -> ScoreItem? {
    score?.items.first { $0.part == part }
}

@Test func perfectIntervalAtParScoresAboutEightySeven() {
    let blocks = intervalBlocks()
    let score = scoreWorkout(blocks: blocks, zones: zones, previous: occurrences(blocks, count: 3))

    #expect(score?.value == 88)
    #expect(item(score, .execution) == ScoreItem(part: .execution, points: 50, maximum: 50, reason: nil))
    #expect(item(score, .intent) == ScoreItem(part: .intent, points: 25, maximum: 25, reason: nil))
    #expect(item(score, .cost) == ScoreItem(part: .cost, points: 12.5, maximum: 25, reason: nil))
}

@Test func fivePercentMoreEfficientMaxesCost() {
    let reference = intervalBlocks(sprintHeartRate: 170)
    let better = intervalBlocks(sprintHeartRate: 160)
    let score = scoreWorkout(blocks: better, zones: zones, previous: occurrences(reference, count: 3))

    #expect(item(score, .cost) == ScoreItem(part: .cost, points: 25, maximum: 25, reason: .moreEfficient))
}

@Test func fivePercentLessEfficientZeroesCost() {
    let reference = intervalBlocks(sprintHeartRate: 170)
    let worse = intervalBlocks(sprintHeartRate: 179)
    let score = scoreWorkout(blocks: worse, zones: zones, previous: occurrences(reference, count: 3))

    #expect(item(score, .cost) == ScoreItem(part: .cost, points: 0, maximum: 25, reason: .lessEfficient))
}

@Test func incompleteBlockCreditsExecutedFraction() {
    let step = PrescribedStep(index: 0, intensity: .active, duration: .distance(meters: 2000), target: .speed(low: 3.8, high: 4.2))
    let blocks = [block(.active, step: step, status: .incomplete, seconds: 250, distance: 1000, heartRate: 170)]
    let score = scoreWorkout(blocks: blocks, zones: zones, previous: [])

    #expect(item(score, .execution) == ScoreItem(part: .execution, points: 25, maximum: 50, reason: .incompleteStep))
}

@Test func notExecutedBlockCountsZero() {
    var blocks = intervalBlocks()
    blocks.append(block(.active, step: sprintStep, status: .notExecuted, seconds: 0, distance: 0, heartRate: nil))
    let score = scoreWorkout(blocks: blocks, zones: zones, previous: [])

    #expect(item(score, .execution)?.reason == .notExecuted)
    #expect(item(score, .execution)?.points == 50.0 * 6 / 7)
}

@Test func easyRunTooHardLosesIntent() {
    let step = PrescribedStep(index: 0, intensity: .active, duration: .time(seconds: 1800), target: .heartRateZone(2))
    let blocks = [block(.active, step: step, status: .aboveTarget, seconds: 1800, distance: 5000, heartRate: 165)]
    let score = scoreWorkout(blocks: blocks, zones: zones, previous: [])

    #expect((item(score, .intent)?.points ?? 25) < 25)
    #expect(item(score, .intent)?.reason == .easyTooHard)
}

@Test func paceBlockTooEasyLosesIntent() {
    let blocks = intervalBlocks(sprintHeartRate: 110)
    let score = scoreWorkout(blocks: blocks, zones: zones, previous: [])

    #expect(item(score, .intent)?.reason == .hardTooEasy)
    #expect(abs((item(score, .intent)?.points ?? 0) - 25.0 / 3) < 1e-9)
}

@Test func heartRateTargetMissedLosesIntent() {
    let step = PrescribedStep(index: 0, intensity: .active, duration: .time(seconds: 1200), target: .heartRateZone(4))
    let blocks = [block(.active, step: step, status: .belowTarget, seconds: 1200, distance: 4000, heartRate: 150)]
    let score = scoreWorkout(blocks: blocks, zones: zones, previous: [])

    #expect(item(score, .intent)?.points == 0)
    #expect(item(score, .intent)?.reason == .heartRateTargetMissed)
}

@Test func recoveryIsIgnoredForIntent() {
    let calm = scoreWorkout(blocks: intervalBlocks(recoveryHeartRate: 120), zones: zones, previous: [])
    let hot = scoreWorkout(blocks: intervalBlocks(recoveryHeartRate: 168), zones: zones, previous: [])

    #expect(item(calm, .intent) == item(hot, .intent))
    #expect(item(hot, .intent)?.points == 25)
}

@Test func freeRunScoresOnlyCost() {
    let blocks = [block(.active, step: nil, status: .noTarget, seconds: 1800, distance: 6000, heartRate: 150)]
    let score = scoreWorkout(blocks: blocks, zones: zones, previous: occurrences(blocks, count: 2))

    #expect(item(score, .execution) == ScoreItem(part: .execution, points: 0, maximum: 0, reason: .noPrescription))
    #expect(item(score, .intent) == ScoreItem(part: .intent, points: 0, maximum: 0, reason: .noPrescription))
    #expect(score?.value == 50)
}

@Test func noHeartRateScoresOnlyExecution() {
    let blocks = intervalBlocks().map { block -> WorkoutBlock in
        var copy = block
        copy.avgHeartRate = nil
        return copy
    }
    let score = scoreWorkout(blocks: blocks, zones: zones, previous: occurrences(blocks, count: 2))

    #expect(item(score, .intent) == ScoreItem(part: .intent, points: 0, maximum: 0, reason: .noHeartRate))
    #expect(item(score, .cost) == ScoreItem(part: .cost, points: 0, maximum: 0, reason: .noHeartRate))
    #expect(score?.value == 100)
}

@Test func noZonesDropsIntent() {
    let blocks = intervalBlocks()
    let score = scoreWorkout(blocks: blocks, zones: nil, previous: occurrences(blocks, count: 2))

    #expect(item(score, .intent) == ScoreItem(part: .intent, points: 0, maximum: 0, reason: .noZones))
    #expect(score?.value == 83)
}

@Test func noHistoryDropsCost() {
    let score = scoreWorkout(blocks: intervalBlocks(), zones: zones, previous: [])

    #expect(item(score, .cost) == ScoreItem(part: .cost, points: 0, maximum: 0, reason: .noHistory))
    #expect(score?.value == 100)
}

@Test func emptyBlocksHaveNoScore() {
    #expect(scoreWorkout(blocks: [], zones: zones, previous: []) == nil)
}
