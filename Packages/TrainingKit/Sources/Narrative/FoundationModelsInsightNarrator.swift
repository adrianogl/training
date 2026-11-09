import Foundation
import FoundationModels
import Metrics

@Generable
struct InsightDraft {
    @Guide(description: "Uma frase curta em português, escrita como um treinador falaria")
    var sentence: String
}

struct LanguageModelInsightGenerator: InsightGenerator {
    func generate(instructions: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: prompt,
            generating: InsightDraft.self,
            options: GenerationOptions(temperature: NarrativeConstants.temperature)
        )
        return response.content.sentence
    }
}

public struct FoundationModelsInsightNarrator: InsightNarrator {
    private let generator: any InsightGenerator

    public init() {
        self.init(generator: LanguageModelInsightGenerator())
    }

    init(generator: any InsightGenerator) {
        self.generator = generator
    }

    public func readinessSentence(_ breakdown: ReadinessBreakdown, verdict: ReadinessVerdict) async -> String {
        let template = TemplateInsightNarrator.readinessSentence(breakdown, verdict: verdict)
        return await validated(instructions: InsightNarrativeConstants.readinessInstructions, template: template)
    }

    public func overallSentence(_ facts: OverallFacts) async -> String {
        let template = TemplateInsightNarrator.overallSentence(facts)
        return await validated(instructions: InsightNarrativeConstants.overallInstructions, template: template)
    }

    private func validated(instructions: String, template: String) async -> String {
        let prompt = "\(InsightNarrativeConstants.referenceHeader) \(template)"
        guard let generated = try? await generator.generate(instructions: instructions, prompt: prompt) else { return template }
        let text = generated.trimmingCharacters(in: .whitespacesAndNewlines)
        return NarrativeCheck.matches(text, template: template, words: []) ? text : template
    }
}

public func makeInsightNarrator() -> any InsightNarrator {
    SystemLanguageModel.default.availability == .available ? FoundationModelsInsightNarrator() : TemplateInsightNarrator()
}
