import Narrative

actor CoachFeedbackCache {
    static let shared = CoachFeedbackCache()

    private var texts: [[String]: String] = [:]
    private var misses: Set<[String]> = []

    func text(for facts: [String]) async -> String? {
        if let cached = texts[facts] { return cached }
        guard !misses.contains(facts) else { return nil }
        guard let text = await CoachFeedback.rewrite(facts: facts) else {
            misses.insert(facts)
            return nil
        }
        texts[facts] = text
        return text
    }
}
