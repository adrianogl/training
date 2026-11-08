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
        let evolutionText = evolution == nil ? nil : Self.trimmed(draft.evolution)
        let allowedNumbers = Self.numbers(in: prompt)
        let output = sentences + [evolutionText].compactMap { $0 }
        guard sentences.count == findings.count,
              !output.contains(where: \.isEmpty),
              !output.contains(where: Self.copiesFormat),
              output.allSatisfy({ Self.numbers(in: $0).isSubset(of: allowedNumbers) }) else {
            return template
        }
        return WorkoutNarrative(findings: sentences, evolution: evolutionText, generatedBy: NarrativeConstants.foundationModelsSource)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func copiesFormat(_ text: String) -> Bool {
        NarrativeConstants.forbiddenFragments.contains { text.contains($0) }
    }

    private static func numbers(in text: String) -> Set<String> {
        Set(text.matches(of: /\d+/).map { String($0.output) })
    }
}
