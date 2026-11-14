import FITReader
import Testing
import WorkoutAnalysis
@testable import Narrative

private func active(_ ordinal: Int, label: String, status: BlockStatus, seconds: Double = 240) -> WorkoutBlock {
    WorkoutBlock(
        kind: .active, ordinal: ordinal, label: label,
        prescribed: PrescribedStep(index: ordinal, intensity: .active, duration: .distance(meters: 1_000), target: .speed(low: 1_000.0 / 245, high: 1_000.0 / 235)),
        laps: [], seconds: seconds, distance: 1_000, avgSpeed: 1_000.0 / seconds, avgHeartRate: 172,
        maxHeartRate: 178, dominantZone: 5, status: status
    )
}

private func recovery(_ ordinal: Int, heartRate: Int) -> WorkoutBlock {
    WorkoutBlock(
        kind: .recovery, ordinal: ordinal, label: "Recuperação \(ordinal)", prescribed: nil, laps: [],
        seconds: 120, distance: 300, avgSpeed: 2.5, avgHeartRate: heartRate,
        maxHeartRate: heartRate + 6, dominantZone: 3, status: .noTarget
    )
}

private let blocks = [
    active(0, label: "Tiro 1", status: .inTarget, seconds: 238),
    recovery(1, heartRate: 140),
    active(2, label: "Tiro 2", status: .inTarget, seconds: 241),
    recovery(3, heartRate: 146),
    active(4, label: "Tiro 3", status: .slower, seconds: 248),
]

@Suite struct FindingDetailTests {
    @Test func blockInTargetListsPacesOfBlocksInTarget() {
        let finding = Finding(group: .positive, kind: .blockInTarget, blockOrdinal: nil, facts: [FindingFact.inTarget: 2, FindingFact.total: 3])

        #expect(FindingDetail.evidence(finding, blocks: blocks) == "3:58 · 4:01 /km")
        #expect(FindingDetail.why(finding, blocks: blocks) == FindingDetailConstants.whySomeInTarget)
    }

    @Test func slowerBlockAfterHardestRecoveryExplainsFatigue() {
        let finding = Finding(group: .negative, kind: .blockOffTarget, blockOrdinal: 4, facts: [
            FindingFact.speed: 1_000.0 / 248, FindingFact.heartRate: 172,
            FindingFact.targetLow: 1_000.0 / 245, FindingFact.targetHigh: 1_000.0 / 235,
            FindingFact.recoveryHeartRate: 146, FindingFact.recoveryHighest: 1,
        ])

        #expect(FindingDetail.evidence(finding, blocks: blocks) == "4:08 /km · alvo 3:55–4:05 /km · FC 172 bpm")
        let why = FindingDetail.why(finding, blocks: blocks)
        #expect(why.contains("146 bpm"))
        #expect(why.contains("a mais alta do treino"))
    }

    @Test func everyKindHasWhyAndEvidenceUsesItsFacts() {
        let cases: [(Finding, String)] = [
            (Finding(group: .positive, kind: .steadyPace, blockOrdinal: 0, facts: [
                FindingFact.spread: 4, FindingFact.fastestPace: 298, FindingFact.slowestPace: 302,
            ]), "voltas de 4:58 a 5:02 /km"),
            (Finding(group: .positive, kind: .lowerHeartRateThanBefore, blockOrdinal: 0, facts: [
                FindingFact.delta: 4, FindingFact.heartRate: 171, FindingFact.beforeHeartRate: 175, FindingFact.speed: 1_000.0 / 241,
            ]), "171 bpm vs. 175 bpm · 4:01 /km"),
            (Finding(group: .positive, kind: .goodRecovery, blockOrdinal: 1, facts: [
                FindingFact.drop: 38, FindingFact.peak: 178, FindingFact.recovered: 140,
            ]), "pico 178 bpm → média 140 bpm"),
            (Finding(group: .negative, kind: .stepIncomplete, blockOrdinal: 4, facts: [
                FindingFact.distance: 800, FindingFact.seconds: 200, FindingFact.targetDistance: 1_000,
            ]), "feito 800 m de 1,00 km"),
            (Finding(group: .negative, kind: .paceFade, blockOrdinal: 0, facts: [
                FindingFact.fade: 9, FindingFact.lastPace: 317, FindingFact.medianPace: 308,
            ]), "última volta 5:17 · mediana 5:08 /km"),
            (Finding(group: .attention, kind: .cardiacDrift, blockOrdinal: 0, facts: [
                FindingFact.rise: 0.06, FindingFact.fromHR: 150, FindingFact.toHR: 159,
            ]), "FC 150 → 159 bpm · +6%"),
            (Finding(group: .attention, kind: .zoneAboveTarget, blockOrdinal: 1, facts: [
                FindingFact.zone: 3, FindingFact.speed: 2.5, FindingFact.heartRate: 146,
            ]), "6:40 /km · FC 146 bpm"),
            (Finding(group: .attention, kind: .hardOnLowReadiness, blockOrdinal: nil, facts: [FindingFact.readiness: 42]), "prontidão 42 de 100 · limite 50"),
            (Finding(group: .attention, kind: .highAcuteChronic, blockOrdinal: nil, facts: [FindingFact.ratio: 1.62]), "razão 1,62 · limite 1,50"),
        ]
        for (finding, evidence) in cases {
            #expect(FindingDetail.evidence(finding, blocks: blocks) == evidence)
            #expect(!FindingDetail.why(finding, blocks: blocks).isEmpty)
        }
    }

    @Test func missingFactsGiveNoEvidence() {
        let finding = Finding(group: .positive, kind: .steadyPace, blockOrdinal: 0, facts: [FindingFact.spread: 4])

        #expect(FindingDetail.evidence(finding, blocks: blocks) == nil)
    }
}
