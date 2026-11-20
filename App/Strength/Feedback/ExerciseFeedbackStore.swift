import Foundation

struct ExerciseFeedbackStore: Sendable {
    let url: URL
    let stamps: SyncDocumentStamp?
    var moveAside: (@Sendable (URL, URL) throws -> Void)?

    private var file: JSONFileStore<ExerciseFeedback> {
        guard let moveAside else { return JSONFileStore(url: url) }
        return JSONFileStore(url: url, moveAside: moveAside)
    }

    init(url: URL, stamps: SyncDocumentStamp? = nil) {
        self.url = url
        self.stamps = stamps
    }

    func all() -> [ExerciseFeedback] {
        file.read()
    }

    func save(_ entry: ExerciseFeedback) throws {
        defer { stamps?.bumpForLocalChange(newestEntry: all().map(\.updatedAt).max()) }
        try file.mutate { entries in
            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[index] = entry
            } else {
                entries.append(entry)
            }
            return true
        }
    }

    func latest(for key: ExerciseKey, mediaId: String) -> ExerciseFeedback? {
        all().filter { $0.exercise == key && $0.mediaId == mediaId }.max { $0.updatedAt < $1.updatedAt }
    }

    func preferredChoice(for key: ExerciseKey) -> ExerciseFeedback? {
        let entries = all().filter { $0.exercise == key }
        let undone = Set(entries.compactMap(\.undoes))
        return entries
            .filter { $0.chosenMediaId != nil && !undone.contains($0.id) }
            .max { $0.updatedAt < $1.updatedAt }
    }

    func preferredMediaId(for key: ExerciseKey) -> String? {
        preferredChoice(for: key)?.chosenMediaId
    }

    func merge(_ remote: [ExerciseFeedback]) -> Bool {
        let applied = try? file.mutate { entries in
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
            return changed
        }
        return applied ?? false
    }
}
