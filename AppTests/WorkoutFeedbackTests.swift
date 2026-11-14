import FITReader
import Testing
import WorkoutAnalysis
@testable import trAIning

@Suite struct WorkoutFeedbackTests {
    private static let target = StepTarget.speed(low: 1_000.0 / 224, high: 1_000.0 / 211)

    private static func repeatBlock(_ ordinal: Int, seconds: Double, heartRate: Int, status: BlockStatus) -> WorkoutBlock {
        WorkoutBlock(
            kind: .active, ordinal: ordinal, label: "Tiro \(ordinal)",
            prescribed: PrescribedStep(index: ordinal, intensity: .active, duration: .distance(meters: 1_000), target: target),
            laps: [], seconds: seconds, distance: 1_000, avgSpeed: 1_000 / seconds, avgHeartRate: heartRate,
            maxHeartRate: heartRate + 8, dominantZone: 4, status: status
        )
    }

    private static func recovery(_ ordinal: Int, heartRate: Int) -> WorkoutBlock {
        WorkoutBlock(
            kind: .recovery, ordinal: ordinal, label: "Recuperação \(ordinal)",
            prescribed: PrescribedStep(index: 100 + ordinal, intensity: .recovery, duration: .time(seconds: 120), target: .open),
            laps: [], seconds: 120, distance: 330, avgSpeed: 2.75, avgHeartRate: heartRate,
            maxHeartRate: heartRate + 6, dominantZone: 3, status: .noTarget
        )
    }

    private static let blocks: [WorkoutBlock] = [
        repeatBlock(1, seconds: 214, heartRate: 150, status: .inTarget),
        recovery(1, heartRate: 135),
        repeatBlock(2, seconds: 226, heartRate: 155, status: .slower),
        recovery(2, heartRate: 140),
        repeatBlock(3, seconds: 217, heartRate: 158, status: .inTarget),
        recovery(3, heartRate: 148),
        repeatBlock(4, seconds: 225, heartRate: 160, status: .slower),
        recovery(4, heartRate: 128),
        repeatBlock(5, seconds: 218, heartRate: 161, status: .inTarget),
    ]

    @Test func namesBlocksInFullAndGroupsRepeatedFindings() {
        let assessment = WorkoutAssessment(
            positives: [
                Finding(group: .positive, kind: .blockInTarget, blockOrdinal: nil, facts: [FindingFact.inTarget: 3, FindingFact.total: 5]),
            ],
            negatives: [
                Finding(group: .negative, kind: .blockOffTarget, blockOrdinal: 2, facts: [
                    FindingFact.speed: 1_000 / 226, FindingFact.targetLow: 1_000.0 / 224, FindingFact.targetHigh: 1_000.0 / 211,
                    FindingFact.recoveryHeartRate: 135, FindingFact.recoveryHighest: 0,
                ]),
                Finding(group: .negative, kind: .blockOffTarget, blockOrdinal: 6, facts: [
                    FindingFact.speed: 1_000 / 225, FindingFact.targetLow: 1_000.0 / 224, FindingFact.targetHigh: 1_000.0 / 211,
                    FindingFact.recoveryHeartRate: 148, FindingFact.recoveryHighest: 1,
                ]),
            ],
            attention: [
                Finding(group: .attention, kind: .zoneAboveTarget, blockOrdinal: 5, facts: [FindingFact.zone: 3, FindingFact.heartRate: 148, FindingFact.speed: 2.75]),
            ]
        )

        let summary = WorkoutFeedback.summary(assessment: assessment, blocks: Self.blocks)

        #expect(summary.entries.map(\.title) == [
            "Segundo e quarto tiros de 1000 m mais lentos que o alvo",
            "Recuperação depois do terceiro tiro em Z3",
            "3 de 5 tiros de 1000 m no alvo",
        ])
        #expect(summary.entries.map(\.tag) == [.fix, .fix, .expected])
        #expect(summary.entries[0].evidence == "3:46 e 3:45 /km · alvo 3:31–3:44")
        #expect(summary.entries[0].why.contains("quarto tiro de 1000 m"))
        #expect(summary.entries[1].why.contains("O quarto tiro de 1000 m, logo depois, ficou abaixo do alvo."))
        #expect(summary.feedback.first == "Bom treino: 3 dos 5 tiros de 1000 m saíram no alvo, com média de 3:40/km.")
        #expect(summary.next == WorkoutFeedbackConstants.nextSlower)
    }

    @Test func runOfRecoveriesUsesRange() {
        let name = BlockNaming.name([1, 3, 5], blocks: Self.blocks)

        #expect(name?.text == "recuperações do primeiro ao terceiro tiro")
        #expect(name?.feminine == true)
    }

    @Test func tableLabelShowsOrdinalAndPrescribedSize() {
        #expect(BlockNaming.tableLabel(Self.blocks[2]).title == "2º tiro")
        #expect(BlockNaming.tableLabel(Self.blocks[2]).detail == "1000 m")
        #expect(BlockNaming.tableLabel(Self.blocks[1]).title == "Trote")
        #expect(BlockNaming.tableLabel(Self.blocks[1]).detail == "2 min")
    }
}
