import Testing
import WorkoutAnalysis
@testable import Narrative

private struct ThrowingGenerator: NarrativeGenerator {
    struct Failure: Error {}

    func generate(instructions: String, prompt: String) async throws -> GeneratedNarrative {
        throw Failure()
    }
}

private struct FixedGenerator: NarrativeGenerator {
    let output: GeneratedNarrative

    func generate(instructions: String, prompt: String) async throws -> GeneratedNarrative {
        output
    }
}

private func block(_ ordinal: Int, label: String, status: BlockStatus = .inTarget) -> WorkoutBlock {
    WorkoutBlock(
        kind: .active, ordinal: ordinal, label: label, prescribed: nil, laps: [],
        seconds: 245, distance: 1_000, avgSpeed: 1_000.0 / 245, avgHeartRate: 168,
        maxHeartRate: 174, dominantZone: 4, status: status
    )
}

private let blocks = [
    WorkoutBlock(
        kind: .warmup, ordinal: 0, label: "Aquecimento", prescribed: nil, laps: [],
        seconds: 360, distance: 1_000, avgSpeed: 1_000.0 / 360, avgHeartRate: 130,
        maxHeartRate: 136, dominantZone: 2, status: .noTarget
    ),
    block(1, label: "Tiro 1", status: .slower),
    block(2, label: "Recuperação 1"),
]

private let assessment = WorkoutAssessment(
    positives: [Finding(group: .positive, kind: .blockInTarget, blockOrdinal: nil, facts: [FindingFact.inTarget: 2, FindingFact.total: 3])],
    negatives: [Finding(group: .negative, kind: .paceFade, blockOrdinal: 1, facts: [FindingFact.fade: 9])],
    attention: []
)

private let evolution = EvolutionFacts(paceDelta: -5, heartRateDelta: 0.4, oldestDate: "1 de nov.")

@Suite struct NarratorTests {
    @Test func templateCoversEveryKind() {
        let cases: [(Finding, String)] = [
            (Finding(group: .positive, kind: .blockInTarget, blockOrdinal: nil, facts: [FindingFact.inTarget: 5, FindingFact.total: 6]), "5 de 6"),
            (Finding(group: .positive, kind: .steadyPace, blockOrdinal: 1, facts: [FindingFact.spread: 4]), "4 s/km"),
            (Finding(group: .positive, kind: .lowerHeartRateThanBefore, blockOrdinal: 1, facts: [FindingFact.delta: 5]), "5 bpm"),
            (Finding(group: .positive, kind: .goodRecovery, blockOrdinal: 2, facts: [FindingFact.drop: 31]), "31 bpm"),
            (Finding(group: .negative, kind: .blockOffTarget, blockOrdinal: 1, facts: [
                FindingFact.speed: 1_000.0 / 245, FindingFact.targetLow: 1_000.0 / 250, FindingFact.targetHigh: 1_000.0 / 240,
            ]), "4:05 /km"),
            (Finding(group: .negative, kind: .stepIncomplete, blockOrdinal: 1, facts: [
                FindingFact.distance: 800, FindingFact.seconds: 200, FindingFact.targetDistance: 1_000,
            ]), "800 m"),
            (Finding(group: .negative, kind: .paceFade, blockOrdinal: 1, facts: [FindingFact.fade: 9]), "9 s/km"),
            (Finding(group: .attention, kind: .cardiacDrift, blockOrdinal: 1, facts: [
                FindingFact.rise: 0.06, FindingFact.fromHR: 150, FindingFact.toHR: 159,
            ]), "159 bpm"),
            (Finding(group: .attention, kind: .zoneAboveTarget, blockOrdinal: 0, facts: [FindingFact.zone: 3]), "Z3"),
            (Finding(group: .attention, kind: .hardOnLowReadiness, blockOrdinal: nil, facts: [FindingFact.readiness: 42]), "42"),
            (Finding(group: .attention, kind: .highAcuteChronic, blockOrdinal: nil, facts: [FindingFact.ratio: 1.62]), "1,62"),
        ]
        let kinds: Set<FindingKind> = [
            .blockInTarget, .steadyPace, .lowerHeartRateThanBefore, .goodRecovery, .blockOffTarget, .stepIncomplete,
            .paceFade, .cardiacDrift, .zoneAboveTarget, .hardOnLowReadiness, .highAcuteChronic,
        ]
        #expect(Set(cases.map(\.0.kind)) == kinds)
        for (finding, number) in cases {
            let text = TemplateNarrator.text(finding, blocks: blocks)
            #expect(!text.isEmpty, "\(finding.kind)")
            #expect(text.contains(number), "\(finding.kind): \(text)")
        }
        let offTarget = TemplateNarrator.text(cases[4].0, blocks: blocks)
        #expect(offTarget.contains("Tiro 1"))
        #expect(offTarget.contains("mais lento que o prescrito"))
        #expect(offTarget.contains("4:00–4:10"))
    }

    @Test func templateKeepsFindingOrderAndEvolution() {
        let narrative = TemplateNarrator().narrative(assessment, blocks: blocks, evolution: evolution)

        #expect(narrative.generatedBy == "template")
        #expect(narrative.findings.count == 2)
        #expect(narrative.findings[0].contains("2 de 3"))
        #expect(narrative.findings[1].contains("9 s/km"))
        #expect(narrative.evolution == "5 s/km mais rápido, FC igual, em relação a 1 de nov.")
    }

    @Test func fallsBackOnError() async {
        let narrator = FoundationModelsNarrator(generator: ThrowingGenerator())

        let narrative = await narrator.narrate(assessment, blocks: blocks, evolution: evolution)

        #expect(narrative == TemplateNarrator().narrative(assessment, blocks: blocks, evolution: evolution))
        #expect(narrative.generatedBy == "template")
    }

    @Test func fallsBackOnCountMismatch() async {
        let narrator = FoundationModelsNarrator(generator: FixedGenerator(output: GeneratedNarrative(
            findings: ["2 de 3 tiros no alvo."],
            evolution: "5 s/km mais rápido que em 1 de nov."
        )))

        let narrative = await narrator.narrate(assessment, blocks: blocks, evolution: evolution)

        #expect(narrative.generatedBy == "template")
        #expect(narrative.findings.count == 2)
    }

    @Test func fallsBackOnEmptySentence() async {
        let narrator = FoundationModelsNarrator(generator: FixedGenerator(output: GeneratedNarrative(
            findings: ["2 de 3 tiros no alvo.", "  "],
            evolution: "5 s/km mais rápido que em 1 de nov."
        )))

        let narrative = await narrator.narrate(assessment, blocks: blocks, evolution: evolution)

        #expect(narrative.generatedBy == "template")
    }

    @Test func fallsBackOnInventedNumber() async {
        let narrator = FoundationModelsNarrator(generator: FixedGenerator(output: GeneratedNarrative(
            findings: ["2 de 3 tiros no alvo.", "O Tiro 1 perdeu 12 s/km no fim."],
            evolution: "5 s/km mais rápido que em 1 de nov."
        )))

        let narrative = await narrator.narrate(assessment, blocks: blocks, evolution: evolution)

        #expect(narrative.generatedBy == "template")
    }

    @Test func fallsBackWhenModelCopiesFacts() async {
        let narrator = FoundationModelsNarrator(generator: FixedGenerator(output: GeneratedNarrative(
            findings: ["Achado 1, positivo: 2 de 3", "O Tiro 1 perdeu 9 s/km na última volta."],
            evolution: "5 s/km mais rápido que em 1 de nov."
        )))

        let narrative = await narrator.narrate(assessment, blocks: blocks, evolution: evolution)

        #expect(narrative.generatedBy == "template")
    }

    @Test func usesModelSentencesWhenValid() async {
        let output = GeneratedNarrative(
            findings: ["2 de 3 tiros no alvo.", "O Tiro 1 perdeu 9 s/km na última volta."],
            evolution: "5 s/km mais rápido que em 1 de nov., com a FC igual."
        )
        let narrator = FoundationModelsNarrator(generator: FixedGenerator(output: output))

        let narrative = await narrator.narrate(assessment, blocks: blocks, evolution: evolution)

        #expect(narrative == WorkoutNarrative(findings: output.findings, evolution: output.evolution, generatedBy: "foundation-models"))
    }

    @Test func dropsModelEvolutionWithoutFacts() async {
        let narrator = FoundationModelsNarrator(generator: FixedGenerator(output: GeneratedNarrative(
            findings: ["2 de 3 tiros no alvo.", "O Tiro 1 perdeu 9 s/km na última volta."],
            evolution: ""
        )))

        let narrative = await narrator.narrate(assessment, blocks: blocks, evolution: nil)

        #expect(narrative.generatedBy == "foundation-models")
        #expect(narrative.evolution == nil)
    }

    @Test func promptCarriesFormattedFacts() {
        let prompt = NarrativePrompt.text(assessment.orderedFindings, blocks: blocks, evolution: evolution)

        #expect(prompt.contains("Tiro 1"))
        #expect(prompt.contains("9 s/km"))
        #expect(prompt.contains("2 de 3 blocos ativos dentro do alvo prescrito"))
        #expect(prompt.contains("Evolução: 5 s/km mais rápido, FC igual, em relação a 1 de nov."))
        #expect(prompt.contains("5 s/km mais rápido"))
        #expect(!prompt.contains("0.4"))
    }
}
