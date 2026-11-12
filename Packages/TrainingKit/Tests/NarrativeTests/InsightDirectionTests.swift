import Metrics
import Testing
@testable import Narrative

private struct FixedInsightGenerator: InsightGenerator {
    let output: String

    func generate(instructions: String, prompt: String) async throws -> String {
        output
    }
}

private func facts(_ verdict: OverallVerdict, goalGap: Double? = nil) -> OverallFacts {
    OverallFacts(verdict: verdict, improved: 5, worsened: 5, total: 8, goalGapSeconds: goalGap, raceDayGapSeconds: nil)
}

private let breakdown = ReadinessBreakdown(score: 74, normal: 70, factors: [])

@Suite struct InsightDirectionTests {
    @Test func overallWorseRejectsMelhor() async {
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: "Você está melhor que há 3 meses: 5 de 8 indicadores pioraram."))
        let text = await narrator.overallSentence(facts(.worse))
        #expect(text == TemplateInsightNarrator.overallSentence(facts(.worse)))
    }

    @Test func overallBetterAcceptsMelhor() async {
        let generated = "Você está melhor que há 3 meses: 5 de 8 indicadores melhoraram."
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: generated))
        let text = await narrator.overallSentence(facts(.better))
        #expect(text == generated)
    }

    @Test func readinessRestRejectsForte() async {
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: "Prontidão 74, dá para treinar forte hoje."))
        let text = await narrator.readinessSentence(breakdown, verdict: .rest)
        #expect(text == TemplateInsightNarrator.readinessSentence(breakdown, verdict: .rest))
    }

    @Test func goalGapDirectionChecked() async {
        for gap in [125.0, -125.0] {
            let withGap = facts(.stable, goalGap: gap)
            for word in ["acima", "abaixo"] {
                let output = "Estável em relação a 3 meses atrás, previsão \(word) da meta: faltam 2:05."
                let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: output))
                #expect(await narrator.overallSentence(withGap) == TemplateInsightNarrator.overallSentence(withGap))
            }
        }
        let noGap = facts(.stable)
        let output = "Estável em relação a 3 meses atrás, com a previsão acima do que você esperava."
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: output))
        #expect(await narrator.overallSentence(noGap) == output)
    }

    @Test func worseAcceptsPiorou() async {
        let generated = "Você piorou em relação a 3 meses atrás: 5 de 8 indicadores."
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: generated))
        #expect(await narrator.overallSentence(facts(.worse)) == generated)
    }

    @Test func betterAcceptsMelhoraram() async {
        let generated = "Em relação a 3 meses atrás, 5 de 8 indicadores melhoraram."
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: generated))
        #expect(await narrator.overallSentence(facts(.better)) == generated)
    }

    @Test func sentenceWithoutDirectionWordIsRejected() async {
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: "Em relação a 3 meses atrás, 5 de 8 indicadores mudaram."))
        let worse = facts(.worse)
        #expect(await narrator.overallSentence(worse) == TemplateInsightNarrator.overallSentence(worse))
    }

    @Test(arguments: [OverallVerdict.better, .stable, .worse], [nil, 125.0, -125.0] as [Double?])
    func overallTemplatePassesOwnValidator(verdict: OverallVerdict, gap: Double?) {
        let value = facts(verdict, goalGap: gap)
        let template = TemplateInsightNarrator.overallSentence(value)
        #expect(NarrativeCheck.matches(
            template, template: template, words: [], anyOf: NarrativeCheck.words(value),
            forbidden: NarrativeCheck.forbidden(value), wholeWords: true
        ))
    }

    @Test(arguments: [ReadinessVerdict.rest, .moderate, .hard])
    func readinessTemplatePassesOwnValidator(verdict: ReadinessVerdict) {
        let template = TemplateInsightNarrator.readinessSentence(breakdown, verdict: verdict)
        #expect(NarrativeCheck.matches(
            template, template: template, words: [], anyOf: NarrativeCheck.words(verdict),
            forbidden: NarrativeCheck.forbidden(verdict), wholeWords: true
        ))
    }

    @Test func rejectedFallsBackToTemplate() async {
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: "Melhor que há 3 meses: 5 de 8 indicadores pioraram."))
        let worse = facts(.worse)
        #expect(await narrator.overallSentence(worse) == TemplateInsightNarrator.overallSentence(worse))
        let melhora = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: "Pior que há 3 meses, sem melhora: 5 de 8 indicadores pioraram."))
        #expect(await melhora.overallSentence(worse) == "Pior que há 3 meses, sem melhora: 5 de 8 indicadores pioraram.")
    }
}
