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

    @Test func sectionsSplitWarmupSeriesAndCooldown() {
        let warmup = WorkoutBlock(kind: .warmup, ordinal: 1, label: "Aquecimento", prescribed: nil, laps: [], seconds: 900, distance: 3_000, avgSpeed: 3.3, avgHeartRate: 140, maxHeartRate: 150, dominantZone: 2, status: .noTarget)
        let cooldown = WorkoutBlock(kind: .cooldown, ordinal: 1, label: "Desaquecimento", prescribed: nil, laps: [], seconds: 600, distance: 1_800, avgSpeed: 3, avgHeartRate: 130, maxHeartRate: 140, dominantZone: 1, status: .noTarget)

        let sections = BlockNaming.sections([warmup] + Self.blocks + [cooldown])

        #expect(sections.map(\.title) == ["Aquecimento", "Série · 5 × 1000 m", "Desaquecimento"])
        #expect(sections[1].positions == Array(1...9))
    }

    private static let longRun = [
        WorkoutBlock(
            kind: .active, ordinal: 1, label: "Bloco 1",
            prescribed: PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 20_000), target: .speed(low: 1_000.0 / 300, high: 1_000.0 / 270)),
            laps: [], seconds: 3_482, distance: 12_660, avgSpeed: 12_660 / 3_482, avgHeartRate: 155,
            maxHeartRate: 170, dominantZone: 3, status: .incomplete
        ),
    ]

    private static func incompleteAssessment(_ extra: [String: Double]) -> WorkoutAssessment {
        let facts = [FindingFact.distance: 12_660, FindingFact.seconds: 3_482, FindingFact.targetDistance: 20_000].merging(extra) { $1 }
        return WorkoutAssessment(
            positives: [],
            negatives: [Finding(group: .negative, kind: .stepIncomplete, blockOrdinal: 0, facts: facts)],
            attention: []
        )
    }

    @Test func longRunStoppedEarlyExplainsWhereAndWhy() {
        let assessment = Self.incompleteAssessment([
            FindingFact.fadeKilometer: 10, FindingFact.slowdown: 14.6, FindingFact.heartRateRise: 9,
        ])

        let summary = WorkoutFeedback.summary(assessment: assessment, blocks: Self.longRun, workoutName: "Longão")

        #expect(summary.feedback == [
            "Você fez 12,66 dos 20 km do longão (63%), a 4:35/km.",
            "O pace se manteve até o km 9 e caiu 15 s/km a partir do km 10, e a FC subiu 9 bpm.",
        ])
        #expect(summary.entries.map(\.title) == ["Longão parou no km 12,7"])
        #expect(summary.entries[0].evidence == "12,66 de 20 km · 63%")
        #expect(summary.entries[0].why == "O pace se manteve até o km 9 e caiu 15 s/km a partir do km 10, e a FC subiu 9 bpm.")
        #expect(summary.entries[0].tag == .fix)
        #expect(summary.next == "Comece os primeiros km 15 s/km mais devagar.")
        #expect(!summary.coachFacts.joined().contains("0 dos 1"))
    }

    @Test func longRunWithPauseAdvisesHydrationBeforeThePauseKilometer() {
        let assessment = Self.incompleteAssessment([
            FindingFact.pauseCount: 2, FindingFact.pauseKilometer: 8.2, FindingFact.pauseSeconds: 100, FindingFact.readiness: 42,
        ])

        let summary = WorkoutFeedback.summary(assessment: assessment, blocks: Self.longRun, workoutName: "Longão 20 km")

        #expect(summary.entries[0].why == "Você parou 2 vezes, a primeira no km 8,2, e ficou 1 min 40 s parado no total. A prontidão do dia era 42 de 100.")
        #expect(summary.next == "Beba água ou tome gel antes do km 8. Tente de novo num dia de prontidão melhor.")
    }

    @Test func longRunWithoutSignalsAsksForThePlannedDistanceAndKeepsCauseOut() {
        let summary = WorkoutFeedback.summary(assessment: Self.incompleteAssessment([:]), blocks: Self.longRun, workoutName: nil)

        #expect(summary.feedback == ["Você fez 12,66 dos 20 km do treino (63%), a 4:35/km."])
        #expect(summary.entries[0].title == "Treino parou no km 12,7")
        #expect(summary.entries[0].why == "Faltaram 7,34 km para fechar a distância planejada.")
        #expect(summary.next == "Complete a distância planejada.")
    }

    @Test func intervalsNotDoneAgreeInNumberAndAskForAllBlocks() {
        let notDone = (2 ... 4).map { ordinal in
            var block = Self.repeatBlock(ordinal, seconds: 0, heartRate: 0, status: .notExecuted)
            block.distance = 0
            return block
        }
        let blocks = [Self.repeatBlock(1, seconds: 214, heartRate: 150, status: .inTarget)] + notDone
        let assessment = WorkoutAssessment(
            positives: [Finding(group: .positive, kind: .blockInTarget, blockOrdinal: nil, facts: [FindingFact.inTarget: 1, FindingFact.total: 4])],
            negatives: (1 ... 3).map {
                Finding(group: .negative, kind: .stepIncomplete, blockOrdinal: $0, facts: [FindingFact.distance: 0, FindingFact.targetDistance: 1_000])
            },
            attention: []
        )

        let summary = WorkoutFeedback.summary(assessment: assessment, blocks: blocks)

        #expect(summary.feedback.first == "Treino abaixo do planejado: 1 dos 4 tiros de 1000 m saiu no alvo, com média de 3:34/km.")
        #expect(summary.next == WorkoutFeedbackConstants.nextCompleteBlocks)
    }

    @Test func singleBlockInTargetNeverReadsAsPlural() {
        let blocks = [Self.repeatBlock(1, seconds: 214, heartRate: 150, status: .inTarget)]
        let assessment = WorkoutAssessment(
            positives: [Finding(group: .positive, kind: .blockInTarget, blockOrdinal: nil, facts: [FindingFact.inTarget: 1, FindingFact.total: 1])],
            negatives: [], attention: []
        )

        let summary = WorkoutFeedback.summary(assessment: assessment, blocks: blocks)

        #expect(summary.feedback.first == "Treino cumprido: o tiro de 1000 m saiu no alvo, com média de 3:34/km.")
        #expect(summary.entries.first?.title == "O tiro de 1000 m no alvo")
    }
}
