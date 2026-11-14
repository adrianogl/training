import Foundation
import FoundationModels

public protocol FeedbackGenerator: Sendable {
    func generate(instructions: String, prompt: String) async throws -> String
}

struct LanguageModelFeedbackGenerator: FeedbackGenerator {
    func generate(instructions: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, options: GenerationOptions(temperature: NarrativeConstants.temperature))
        return response.content
    }
}

public enum CoachFeedback {
    public static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    public static func rewrite(facts: [String]) async -> String? {
        guard isAvailable else { return nil }
        return await rewrite(facts: facts, generator: LanguageModelFeedbackGenerator())
    }

    static func rewrite(facts: [String], generator: any FeedbackGenerator) async -> String? {
        let source = facts.joined(separator: "\n")
        guard !source.isEmpty, let draft = try? await generator.generate(instructions: CoachFeedbackConstants.instructions, prompt: source) else {
            return nil
        }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return accepts(text, source: source) ? text : nil
    }

    static func accepts(_ text: String, source: String) -> Bool {
        let sentences = text.split { $0 == "." }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return !text.isEmpty
            && text.count <= CoachFeedbackConstants.maxCharacters
            && sentences.count <= CoachFeedbackConstants.maxSentences
            && !CoachFeedbackConstants.forbidden.contains { text.contains($0) }
            && Set(NarrativeCheck.numbers(in: text)).isSubset(of: Set(NarrativeCheck.numbers(in: source)))
    }
}
