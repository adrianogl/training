import Foundation

struct ExerciseNotesStore: Sendable {
    let url: URL
    let stamps: SyncDocumentStamp?
    var moveAside: (@Sendable (URL, URL) throws -> Void)?

    private var file: JSONFileStore<ExerciseNote> {
        guard let moveAside else { return JSONFileStore(url: url) }
        return JSONFileStore(url: url, moveAside: moveAside)
    }

    init(url: URL = AccountScope.current.exerciseNotesURL, stamps: SyncDocumentStamp? = SyncDocumentStamp(
        defaults: AccountScope.current.defaults, syncedKey: ExerciseNotesConstants.syncedStampKey, documentKey: ExerciseNotesConstants.documentStampKey
    )) {
        self.url = url
        self.stamps = stamps
    }

    func all() -> [ExerciseNote] {
        file.read()
    }

    func allActive() -> [ExerciseNote] {
        all().filter { !$0.deleted }
    }

    func notes(for key: ExerciseKey) -> [ExerciseNote] {
        allActive().filter { $0.exercise == key }.sorted { $0.createdAt < $1.createdAt }
    }

    func save(_ note: ExerciseNote) throws {
        defer { stamps?.bumpForLocalChange(newestEntry: all().map(\.updatedAt).max()) }
        try file.mutate { notes in
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = note
            } else {
                notes.append(note)
            }
            return true
        }
    }

    func delete(_ id: UUID, at now: Date = .now) throws {
        defer { stamps?.bumpForLocalChange(newestEntry: all().map(\.updatedAt).max()) }
        try file.mutate { notes in
            guard let index = notes.firstIndex(where: { $0.id == id }), !notes[index].deleted else { return false }
            notes[index].deleted = true
            notes[index].updatedAt = max(now, notes[index].updatedAt.addingTimeInterval(0.001))
            return true
        }
    }

    func merge(_ remote: [ExerciseNote]) -> Bool {
        let applied = try? file.mutate { notes in
            var changed = false
            for incoming in remote {
                if let index = notes.firstIndex(where: { $0.id == incoming.id }) {
                    let local = notes[index]
                    let newer = incoming.updatedAt > local.updatedAt
                    let deletedAtSameStamp = incoming.updatedAt == local.updatedAt && incoming.deleted && !local.deleted
                    guard newer || deletedAtSameStamp, incoming != local else { continue }
                    notes[index] = incoming
                    changed = true
                } else {
                    notes.append(incoming)
                    changed = true
                }
            }
            return changed
        }
        return applied ?? false
    }
}
