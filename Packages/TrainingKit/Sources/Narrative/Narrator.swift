import FoundationModels
import WorkoutAnalysis

public protocol Narrator: Sendable {
    func narrate(_ assessment: WorkoutAssessment, blocks: [WorkoutBlock], evolution: EvolutionFacts?) async -> WorkoutNarrative
}

public protocol NarrativeGenerator: Sendable {
    func generate(instructions: String, prompt: String) async throws -> GeneratedNarrative
}

public func makeNarrator() -> any Narrator {
    SystemLanguageModel.default.availability == .available ? FoundationModelsNarrator() : TemplateNarrator()
}

extension WorkoutAssessment {
    public var orderedFindings: [Finding] {
        positives + negatives + attention
    }
}
