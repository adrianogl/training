import FITReader
import Testing
@testable import WorkoutAnalysis

private let speedTarget = PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 5000), target: .speed(low: 3.9, high: 4.1))

private func paceLaps(_ paces: [Double], heartRates: [Int]? = nil, meters: Double = 1000) -> [LapSummary] {
    var offset = 0.0
    return paces.enumerated().map { index, pace in
        let seconds = pace * meters / 1000
        defer { offset += seconds }
        return LapSummary(
            stepIndex: 1,
            intensity: .active,
            startOffset: offset,
            timerSeconds: seconds,
            distance: meters,
            avgSpeed: meters / seconds,
            avgHeartRate: heartRates?[index]
        )
    }
}

private func block(
    _ kind: BlockKind = .active,
    label: String = "Bloco 1",
    prescribed: PrescribedStep? = nil,
    laps: [LapSummary] = [],
    seconds: Double = 1250,
    distance: Double = 5000,
    avgSpeed: Double? = 4.0,
    avgHeartRate: Int? = 150,
    maxHeartRate: Int? = 165,
    dominantZone: Int? = 2,
    status: BlockStatus = .noTarget
) -> WorkoutBlock {
    WorkoutBlock(
        kind: kind,
        ordinal: 1,
        label: label,
        prescribed: prescribed,
        laps: laps,
        seconds: seconds,
        distance: distance,
        avgSpeed: avgSpeed,
        avgHeartRate: avgHeartRate,
        maxHeartRate: maxHeartRate,
        dominantZone: dominantZone,
        status: status
    )
}

private func kinds(_ findings: [Finding]) -> [FindingKind] {
    findings.map(\.kind)
}

@Test func allBlocksInTargetIsPositive() {
    let blocks = [
        block(.warmup, label: "Aquecimento"),
        block(label: "Bloco 1", prescribed: speedTarget, status: .inTarget),
        block(label: "Bloco 2", prescribed: speedTarget, status: .inTarget),
    ]

    let assessment = assess(blocks, context: AssessmentContext())

    let finding = assessment.positives.first { $0.kind == .blockInTarget }
    #expect(finding?.group == .positive)
    #expect(finding?.blockOrdinal == nil)
    #expect(finding?.facts[FindingFact.inTarget] == 2)
    #expect(finding?.facts[FindingFact.total] == 2)
    #expect(assessment.positives.filter { $0.kind == .blockInTarget }.count == 1)
}

@Test func noInTargetFindingWhenNoBlockHitsTarget() {
    let blocks = [
        block(label: "Bloco 1", prescribed: speedTarget, status: .slower),
        block(label: "Bloco 2"),
    ]

    let assessment = assess(blocks, context: AssessmentContext())

    #expect(!kinds(assessment.positives).contains(.blockInTarget))
}

@Test func fasterThanTargetIsNegative() {
    let blocks = [
        block(label: "Bloco 1", prescribed: speedTarget, status: .inTarget),
        block(label: "Bloco 2", prescribed: speedTarget, avgSpeed: 4.3, status: .faster),
    ]

    let assessment = assess(blocks, context: AssessmentContext())

    let offTarget = assessment.negatives.filter { $0.kind == .blockOffTarget }
    #expect(offTarget.count == 1)
    #expect(offTarget.first?.blockOrdinal == 1)
    #expect(offTarget.first?.facts[FindingFact.speed] == 4.3)
    #expect(offTarget.first?.facts[FindingFact.targetLow] == 3.9)
    #expect(offTarget.first?.facts[FindingFact.targetHigh] == 4.1)
    #expect(assessment.positives.first { $0.kind == .blockInTarget }?.facts[FindingFact.total] == 2)
}

@Test func blocksInTargetAreNotNegative() {
    let blocks = [block(prescribed: speedTarget, status: .inTarget)]

    let assessment = assess(blocks, context: AssessmentContext())

    #expect(!kinds(assessment.negatives).contains(.blockOffTarget))
}

@Test func incompleteIsNegative() {
    let blocks = [
        block(label: "Bloco 1", prescribed: speedTarget, distance: 3000, status: .incomplete),
        block(label: "Bloco 2", prescribed: speedTarget, laps: [], seconds: 0, distance: 0, avgSpeed: nil, avgHeartRate: nil, status: .notExecuted),
    ]

    let assessment = assess(blocks, context: AssessmentContext())

    let incomplete = assessment.negatives.filter { $0.kind == .stepIncomplete }
    #expect(incomplete.map(\.blockOrdinal) == [0, 1])
    #expect(incomplete.first?.facts[FindingFact.distance] == 3000)
    #expect(incomplete.first?.facts[FindingFact.targetDistance] == 5000)
}

@Test func completeBlocksAreNotIncomplete() {
    let blocks = [block(prescribed: speedTarget, status: .inTarget)]

    let assessment = assess(blocks, context: AssessmentContext())

    #expect(!kinds(assessment.negatives).contains(.stepIncomplete))
}

@Test func steadyPaceDetected() {
    let steady = [block(laps: paceLaps([250, 248, 251, 247, 252]))]
    let uneven = [block(laps: paceLaps([250, 248, 262, 247, 252]))]

    let steadyFinding = assess(steady, context: AssessmentContext()).positives.first { $0.kind == .steadyPace }
    #expect(steadyFinding?.blockOrdinal == 0)
    #expect(abs((steadyFinding?.facts[FindingFact.spread] ?? 0) - 5) < 0.001)
    #expect(!kinds(assess(uneven, context: AssessmentContext()).positives).contains(.steadyPace))
}

@Test func steadyPaceIgnoresShortLapsAndNeedsThreeFullLaps() {
    let withShortLap = [block(laps: paceLaps([250, 249, 251]) + paceLaps([300], meters: 200))]
    let tooFewLaps = [block(laps: paceLaps([250, 250]))]

    #expect(kinds(assess(withShortLap, context: AssessmentContext()).positives).contains(.steadyPace))
    #expect(!kinds(assess(tooFewLaps, context: AssessmentContext()).positives).contains(.steadyPace))
}

@Test func paceFadeIsNegative() {
    let fading = [block(laps: paceLaps([250, 250, 251, 249, 260]))]
    let holding = [block(laps: paceLaps([250, 250, 251, 249, 255]))]

    let finding = assess(fading, context: AssessmentContext()).negatives.first { $0.kind == .paceFade }
    #expect(finding?.blockOrdinal == 0)
    #expect(abs((finding?.facts[FindingFact.fade] ?? 0) - 10) < 0.001)
    #expect(!kinds(assess(holding, context: AssessmentContext()).negatives).contains(.paceFade))
}

@Test func cardiacDriftIsAttention() {
    let blocks = [block(laps: paceLaps(Array(repeating: 250, count: 6), heartRates: [150, 152, 155, 158, 161, 163]))]

    let assessment = assess(blocks, context: AssessmentContext())

    let finding = assessment.attention.first { $0.kind == .cardiacDrift }
    #expect(finding?.group == .attention)
    #expect(finding?.blockOrdinal == 0)
    #expect(abs((finding?.facts[FindingFact.rise] ?? 0) - 0.07) < 0.005)
    #expect(finding?.facts[FindingFact.fromHR] == 151)
    #expect(finding?.facts[FindingFact.toHR] == 162)
}

@Test func noCardiacDriftWhenHeartRateIsFlatOrPaceChanges() {
    let flat = [block(laps: paceLaps(Array(repeating: 250, count: 6), heartRates: [150, 151, 150, 152, 151, 152]))]
    let speedingUp = [block(laps: paceLaps([260, 258, 250, 248, 240, 238], heartRates: [150, 152, 155, 158, 161, 163]))]

    #expect(!kinds(assess(flat, context: AssessmentContext()).attention).contains(.cardiacDrift))
    #expect(!kinds(assess(speedingUp, context: AssessmentContext()).attention).contains(.cardiacDrift))
}

@Test func goodRecoveryIsPositive() {
    let good = [
        block(label: "Tiro 1", maxHeartRate: 180),
        block(.recovery, label: "Recuperação 1", avgHeartRate: 150),
    ]
    let poor = [
        block(label: "Tiro 1", maxHeartRate: 180),
        block(.recovery, label: "Recuperação 1", avgHeartRate: 160),
    ]

    let finding = assess(good, context: AssessmentContext()).positives.first { $0.kind == .goodRecovery }
    #expect(finding?.blockOrdinal == 1)
    #expect(finding?.facts[FindingFact.drop] == 30)
    #expect(!kinds(assess(poor, context: AssessmentContext()).positives).contains(.goodRecovery))
}

@Test func lowerHeartRateThanBeforeIsPositive() {
    let previous = [
        [block(label: "Bloco 1", avgSpeed: 4.0, avgHeartRate: 160)],
        [block(label: "Bloco 1", avgSpeed: 4.0, avgHeartRate: 170)],
    ]
    let context = AssessmentContext(previous: previous)

    let lower = assess([block(label: "Bloco 1", avgSpeed: 4.05, avgHeartRate: 155)], context: context)
    let similar = assess([block(label: "Bloco 1", avgSpeed: 4.0, avgHeartRate: 158)], context: context)
    let faster = assess([block(label: "Bloco 1", avgSpeed: 3.8, avgHeartRate: 150)], context: context)

    let finding = lower.positives.first { $0.kind == .lowerHeartRateThanBefore }
    #expect(finding?.blockOrdinal == 0)
    #expect(finding?.facts[FindingFact.delta] == 5)
    #expect(!kinds(similar.positives).contains(.lowerHeartRateThanBefore))
    #expect(!kinds(faster.positives).contains(.lowerHeartRateThanBefore))
}

@Test func lowerHeartRateUsesMostRecentOccurrenceWithLabel() {
    let previous = [
        [block(label: "Bloco 9", avgSpeed: 4.0, avgHeartRate: 140)],
        [block(label: "Bloco 1", avgSpeed: 4.0, avgHeartRate: 162)],
    ]

    let assessment = assess([block(label: "Bloco 1", avgSpeed: 4.0, avgHeartRate: 155)], context: AssessmentContext(previous: previous))

    #expect(assessment.positives.first { $0.kind == .lowerHeartRateThanBefore }?.facts[FindingFact.delta] == 7)
}

@Test func easyBlockInHighZoneIsAttention() {
    let blocks = [
        block(.warmup, label: "Aquecimento", dominantZone: 3),
        block(label: "Bloco 1", dominantZone: 4),
        block(.cooldown, label: "Desaquecimento", dominantZone: 2),
    ]

    let findings = assess(blocks, context: AssessmentContext()).attention.filter { $0.kind == .zoneAboveTarget }

    #expect(findings.map(\.blockOrdinal) == [0])
    #expect(findings.first?.facts[FindingFact.zone] == 3)
}

@Test func hardWorkoutOnLowReadiness() {
    let hard = [block(prescribed: speedTarget, status: .inTarget)]
    let easy = [block(dominantZone: 2)]

    let finding = assess(hard, context: AssessmentContext(readinessScore: 40)).attention.first { $0.kind == .hardOnLowReadiness }
    #expect(finding?.blockOrdinal == nil)
    #expect(finding?.facts[FindingFact.readiness] == 40)
    #expect(kinds(assess([block(dominantZone: 4)], context: AssessmentContext(readinessScore: 40)).attention).contains(.hardOnLowReadiness))
    #expect(!kinds(assess(hard, context: AssessmentContext(readinessScore: 60)).attention).contains(.hardOnLowReadiness))
    #expect(!kinds(assess(hard, context: AssessmentContext()).attention).contains(.hardOnLowReadiness))
    #expect(!kinds(assess(easy, context: AssessmentContext(readinessScore: 40)).attention).contains(.hardOnLowReadiness))
}

@Test func highAcuteChronicIsAttention() {
    let blocks = [block()]

    let finding = assess(blocks, context: AssessmentContext(acuteChronic: 1.6)).attention.first { $0.kind == .highAcuteChronic }
    #expect(finding?.blockOrdinal == nil)
    #expect(finding?.facts[FindingFact.ratio] == 1.6)
    #expect(!kinds(assess(blocks, context: AssessmentContext(acuteChronic: 1.5)).attention).contains(.highAcuteChronic))
}

@Test func emptyGroupsWhenNothingApplies() {
    let blocks = [
        block(label: "Volta 1", laps: paceLaps([330]), seconds: 330, distance: 1000, avgSpeed: 1000 / 330.0),
        block(label: "Volta 2", laps: paceLaps([335]), seconds: 335, distance: 1000, avgSpeed: 1000 / 335.0),
    ]

    let assessment = assess(blocks, context: AssessmentContext())

    #expect(assessment.positives.isEmpty)
    #expect(assessment.negatives.isEmpty)
    #expect(assessment.attention.isEmpty)
    #expect(assess([], context: AssessmentContext()) == WorkoutAssessment(positives: [], negatives: [], attention: []))
}
