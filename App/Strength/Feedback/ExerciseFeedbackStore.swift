import Foundation

struct ExerciseFeedbackStore: Sendable {
    let url: URL

    private static let lock = NSLock()

    init(url: URL) {
        self.url = url
    }

    func all() -> [ExerciseFeedback] {
        Self.lock.withLock { read() }
    }

    func save(_ entry: ExerciseFeedback) {
        Self.lock.withLock {
            var entries = read()
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index] = entry
            } else {
                entries.append(entry)
            }
            write(entries)
        }
    }

    func latest(for key: ExerciseKey, mediaId: String) -> ExerciseFeedback? {
        all().filter { $0.exercise == key && $0.mediaId == mediaId }.max { $0.updatedAt < $1.updatedAt }
    }

    func preferredMediaId(for key: ExerciseKey) -> String? {
        all()
            .filter { $0.exercise == key && $0.chosenMediaId != nil }
            .max { $0.updatedAt < $1.updatedAt }?
            .chosenMediaId
    }

    func merge(_ remote: [ExerciseFeedback]) -> Bool {
        Self.lock.withLock {
            var entries = read()
            var changed = false
            for incoming in remote {
                if let index = entries.firstIndex(where: { $0.id == incoming.id }) {
                    guard incoming.updatedAt > entries[index].updatedAt, incoming != entries[index] else { continue }
                    entries[index] = incoming
                    changed = true
                } else {
                    entries.append(incoming)
                    changed = true
                }
            }
            if changed { write(entries) }
            return changed
        }
    }

    private func read() -> [ExerciseFeedback] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([ExerciseFeedback].self, from: data)) ?? []
    }

    private func write(_ entries: [ExerciseFeedback]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
