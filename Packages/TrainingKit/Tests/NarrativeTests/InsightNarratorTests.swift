import Metrics
import Testing
@testable import Narrative

private struct FixedInsightGenerator: InsightGenerator {
    let output: String

    func generate(instructions: String, prompt: String) async throws -> String {
        output
    }
}

private struct ThrowingInsightGenerator: InsightGenerator {
    struct Failure: Error {}

    func generate(instructions: String, prompt: String) async throws -> String {
        throw Failure()
    }
}

private func factor(_ component: ReadinessComponent, _ points: Double?) -> ReadinessFactor {
    ReadinessFactor(component: component, todayScore: 70, normalScore: 65, points: points, weight: 0.25)
}

private let mockup = ReadinessBreakdown(score: 74, normal: 70, factors: [
    factor(.hrv, 7.0), factor(.sleep, -2.5), factor(.bodyBattery, 2.0), factor(.load, -0.5),
])

@Suite struct InsightNarratorTests {
    @Test func templateReadinessNamesTopFactors() {
        let breakdown = ReadinessBreakdown(score: 61, normal: 70, factors: [
            factor(.bodyBattery, -6.0), factor(.load, 3.0), factor(.hrv, 1.0),
        ])
        #expect(TemplateInsightNarrator.readinessSentence(breakdown, verdict: .moderate)
            == "Prontidão 61 · treino moderado. Body Battery abaixo do seu normal, carga acima.")
    }

    @Test func morningTextMatchesSpecExample() {
        #expect(morningNotificationText(mockup, verdict: .hard)
            == "Prontidão 74 · pode treinar forte. HRV acima do seu normal, sono abaixo.")
    }

    @Test func morningTextWithOneOrNoFactor() {
        let one = ReadinessBreakdown(score: 74, normal: nil, factors: [factor(.hrv, 4), factor(.sleep, nil)])
        #expect(morningNotificationText(one, verdict: .hard) == "Prontidão 74 · pode treinar forte. HRV acima do seu normal.")
        let none = ReadinessBreakdown(score: 74, normal: nil, factors: [])
        #expect(morningNotificationText(none, verdict: .hard) == "Prontidão 74 · pode treinar forte.")
        #expect(morningNotificationText(none, verdict: .rest) == "Prontidão 74 · dia de descanso.")
    }

    @Test func sleepIsLowercaseAtSentenceStartCapitalized() {
        let breakdown = ReadinessBreakdown(score: 50, normal: nil, factors: [factor(.sleep, -4), factor(.hrv, 1)])
        #expect(morningNotificationText(breakdown, verdict: .rest)
            == "Prontidão 50 · dia de descanso. Sono abaixo do seu normal, HRV acima.")
    }

    @Test func fallsBackWhenGeneratedNumberIsNotAFact() async {
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: "Prontidão 80 · pode treinar forte."))
        let text = await narrator.readinessSentence(mockup, verdict: .hard)
        #expect(text == morningNotificationText(mockup, verdict: .hard))
    }

    @Test func fallsBackWhenGeneratorThrows() async {
        let narrator = FoundationModelsInsightNarrator(generator: ThrowingInsightGenerator())
        let facts = OverallFacts(verdict: .better, improved: 5, worsened: 1, total: 8, goalGapSeconds: nil, raceDayGapSeconds: nil)
        let text = await narrator.overallSentence(facts)
        #expect(text == TemplateInsightNarrator.overallSentence(facts))
    }

    @Test func acceptsGeneratedTextWithSameNumbers() async {
        let generated = "Hoje a prontidão é 74 e você pode treinar forte, com HRV acima do normal."
        let narrator = FoundationModelsInsightNarrator(generator: FixedInsightGenerator(output: generated))
        let text = await narrator.readinessSentence(mockup, verdict: .hard)
        #expect(text == generated)
    }

    @Test func overallTemplateCoversVerdicts() {
        let better = OverallFacts(verdict: .better, improved: 5, worsened: 1, total: 8, goalGapSeconds: nil, raceDayGapSeconds: nil)
        #expect(TemplateInsightNarrator.overallSentence(better) == "Melhor que há 3 meses: 5 de 8 indicadores melhoraram.")
        let stable = OverallFacts(verdict: .stable, improved: 2, worsened: 2, total: 8, goalGapSeconds: nil, raceDayGapSeconds: nil)
        #expect(TemplateInsightNarrator.overallSentence(stable) == "Estável em relação a 3 meses atrás.")
        let worse = OverallFacts(verdict: .worse, improved: 1, worsened: 5, total: 8, goalGapSeconds: 125, raceDayGapSeconds: nil)
        #expect(TemplateInsightNarrator.overallSentence(worse)
            == "Pior que há 3 meses: 5 de 8 indicadores pioraram. Faltam 2:05 para a meta.")
        let long = OverallFacts(verdict: .stable, improved: 0, worsened: 0, total: 8, goalGapSeconds: 3_725, raceDayGapSeconds: nil)
        #expect(TemplateInsightNarrator.overallSentence(long) == "Estável em relação a 3 meses atrás. Faltam 1:02:05 para a meta.")
    }
}
