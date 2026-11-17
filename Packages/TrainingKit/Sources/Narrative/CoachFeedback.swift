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

public struct CoachLimits: Sendable, Equatable {
    public var maxCharacters: Int
    public var maxSentences: Int

    public init(maxCharacters: Int, maxSentences: Int) {
        self.maxCharacters = maxCharacters
        self.maxSentences = maxSentences
    }

    static let standard = CoachLimits(maxCharacters: CoachFeedbackConstants.maxCharacters, maxSentences: CoachFeedbackConstants.maxSentences)
}

public enum CoachFeedback {
    public static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    public static func rewrite(facts: [String]) async -> String? {
        await rewrite(facts: facts, instructions: CoachFeedbackConstants.instructions, limits: .standard)
    }

    public static func rewrite(facts: [String], instructions: String, limits: CoachLimits) async -> String? {
        guard isAvailable else { return nil }
        return await rewrite(facts: facts, instructions: instructions, limits: limits, generator: LanguageModelFeedbackGenerator())
    }

    static func rewrite(facts: [String], generator: any FeedbackGenerator) async -> String? {
        await rewrite(facts: facts, instructions: CoachFeedbackConstants.instructions, limits: .standard, generator: generator)
    }

    public static func rewrite(facts: [String], instructions: String, limits: CoachLimits, generator: any FeedbackGenerator) async -> String? {
        let source = facts.joined(separator: "\n")
        guard !source.isEmpty, let draft = try? await generator.generate(instructions: instructions, prompt: source) else {
            return nil
        }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return accepts(text, source: source, limits: limits) ? text : nil
    }

    static func accepts(_ text: String, source: String, limits: CoachLimits = .standard) -> Bool {
        let sentences = text.split { $0 == "." }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return !text.isEmpty
            && text.count <= limits.maxCharacters
            && sentences.count <= limits.maxSentences
            && !CoachFeedbackConstants.forbidden.contains { text.contains($0) }
            && Set(NarrativeCheck.numbers(in: text)).isSubset(of: Set(NarrativeCheck.numbers(in: source)))
            && !NarrativeCheck.addsTimeUnit(text, source: source)
    }
}
