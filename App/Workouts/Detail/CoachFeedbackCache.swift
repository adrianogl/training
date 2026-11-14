import Narrative

actor CoachFeedbackCache {
    static let shared = CoachFeedbackCache()

    private let store = GeneratedTextStore()
    private var misses: Set<[String]> = []

    func cached(for facts: [String]) -> String? {
        store.text(for: facts)
    }

    func text(for facts: [String]) async -> String? {
        if let cached = cached(for: facts) { return cached }
        guard !misses.contains(facts) else { return nil }
        guard let text = await CoachFeedback.rewrite(facts: facts) else {
            misses.insert(facts)
            return nil
        }
        store.save(text, for: facts)
        return text
    }
}
