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
        let above = facts(.stable, goalGap: 125)
        let wrong = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: "Estável em relação a 3 meses atrás, previsão abaixo da meta: faltam 2:05."))
        #expect(await wrong.overallSentence(above) == TemplateInsightNarrator.overallSentence(above))
        let right = "Estável em relação a 3 meses atrás, com a previsão acima da meta: faltam 2:05."
        let accepted = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: right))
        #expect(await accepted.overallSentence(above) == right)
        let below = facts(.stable, goalGap: -125)
        let inverse = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: "Estável em relação a 3 meses atrás, previsão acima da meta: faltam 2:05."))
        #expect(await inverse.overallSentence(below) == TemplateInsightNarrator.overallSentence(below))
    }

    @Test func rejectedFallsBackToTemplate() async {
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: "Melhor que há 3 meses: 5 de 8 indicadores pioraram."))
        let worse = facts(.worse)
        #expect(await narrator.overallSentence(worse) == TemplateInsightNarrator.overallSentence(worse))
        let melhora = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: "Pior que há 3 meses, sem melhora: 5 de 8 indicadores pioraram."))
        #expect(await melhora.overallSentence(worse) == "Pior que há 3 meses, sem melhora: 5 de 8 indicadores pioraram.")
    }
}
