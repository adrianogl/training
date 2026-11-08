import Foundation
import FoundationModels
import WorkoutAnalysis

@Generable
struct NarrativeDraft {
    @Guide(description: "Uma frase completa e curta, em português, para cada achado, na mesma ordem, escrita como um treinador falaria")
    var findings: [String]

    @Guide(description: "Uma frase curta sobre a evolução, ou texto vazio quando a evolução for nenhuma")
    var evolution: String
}

struct LanguageModelGenerator: NarrativeGenerator {
    func generate(instructions: String, prompt: String) async throws -> GeneratedNarrative {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: prompt,
            generating: NarrativeDraft.self,
            options: GenerationOptions(temperature: NarrativeConstants.temperature)
        )
        return GeneratedNarrative(findings: response.content.findings, evolution: response.content.evolution)
    }
}

public struct FoundationModelsNarrator: Narrator {
    private let generator: any NarrativeGenerator
    private let fallback = TemplateNarrator()

    public init() {
        self.init(generator: LanguageModelGenerator())
    }

    init(generator: any NarrativeGenerator) {
        self.generator = generator
    }

    public func narrate(_ assessment: WorkoutAssessment, blocks: [WorkoutBlock], evolution: EvolutionFacts?) async -> WorkoutNarrative {
        let template = fallback.narrative(assessment, blocks: blocks, evolution: evolution)
        let findings = assessment.orderedFindings
        guard !findings.isEmpty || evolution != nil else { return template }
        let prompt = NarrativePrompt.text(findings, blocks: blocks, evolution: evolution)
        guard let draft = try? await generator.generate(instructions: NarrativeConstants.instructions, prompt: prompt) else {
            return template
        }
        let sentences = draft.findings.map(Self.trimmed)
        guard sentences.count == findings.count else { return template }
        for (index, finding) in findings.enumerated() {
            let words = NarrativeCheck.words(finding, blocks: blocks)
            guard NarrativeCheck.matches(sentences[index], template: template.findings[index], words: words) else { return template }
        }
        var evolutionText: String?
        if let evolution, let expected = template.evolution {
            let text = Self.trimmed(draft.evolution)
            guard NarrativeCheck.matches(text, template: expected, words: NarrativeCheck.words(evolution)) else { return template }
            evolutionText = text
        }
        return WorkoutNarrative(
            findings: sentences,
            evolution: evolutionText,
            generatedBy: NarrativeConstants.foundationModelsSource,
            factsKey: template.factsKey
        )
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
