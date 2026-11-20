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

    func save(_ entry: ExerciseFeedback) throws {
        try Self.lock.withLock {
            preserveCorruptFile()
            var entries = read()
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index] = entry
            } else {
                entries.append(entry)
            }
            try write(entries)
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
            preserveCorruptFile()
            var entries = read()
            var changed = false
            for incoming in remote {
                if let index = entries.firstIndex(where: { $0.id == incoming.id }) {
                    let local = entries[index]
                    let newer = incoming.updatedAt > local.updatedAt
                    let resolvedAtSameStamp = incoming.updatedAt == local.updatedAt && incoming.status == .resolved && local.status == .pending
                    guard newer || resolvedAtSameStamp, incoming != local else { continue }
                    entries[index] = incoming
                    changed = true
                } else {
                    entries.append(incoming)
                    changed = true
                }
            }
            guard changed else { return false }
            return (try? write(entries)) != nil
        }
    }

    private func read() -> [ExerciseFeedback] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([ExerciseFeedback].self, from: data)) ?? []
    }

    private func preserveCorruptFile() {
        guard let data = try? Data(contentsOf: url), (try? JSONDecoder().decode([ExerciseFeedback].self, from: data)) == nil else { return }
        let stamp = Int(Date().timeIntervalSince1970 * 1_000)
        let aside = url.deletingLastPathComponent().appending(path: url.lastPathComponent + ".corrupt-\(stamp)")
        try? FileManager.default.moveItem(at: url, to: aside)
    }

    private func write(_ entries: [ExerciseFeedback]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(entries)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
