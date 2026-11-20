import Foundation
import RemoteSync
import Testing
@testable import trAIning

struct ExerciseNotesTests {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private let key = ExerciseKey.catalog("SQUAT/GOBLET_SQUAT")

    private func makeStore() -> (ExerciseNotesStore, ExerciseNotesSyncStore, URL) {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "notes.json")
        let defaults = UserDefaults(suiteName: "notes-" + UUID().uuidString)!
        let store = ExerciseNotesStore(url: url, stamps: SyncDocumentStamp(defaults: defaults, syncedKey: ExerciseNotesConstants.syncedStampKey, documentKey: ExerciseNotesConstants.documentStampKey))
        return (store, ExerciseNotesSyncStore(store: store, defaults: defaults), url)
    }

    private func note(id: UUID = UUID(), key: ExerciseKey? = nil, text: String = "joelho para fora", at offset: TimeInterval = 0, deleted: Bool = false) -> ExerciseNote {
        ExerciseNote(id: id, exercise: key ?? self.key, text: text, createdAt: base, updatedAt: base.addingTimeInterval(offset), deleted: deleted)
    }

    @Test func note_saved_offline_is_pending() throws {
        let (store, sync, url) = makeStore()
        try store.save(note(at: 4))
        #expect(FileManager.default.fileExists(atPath: url.path))
        let blobs = sync.pendingBlobs()
        #expect(blobs.first?.id == "exerciseNotes")
        sync.markBlobsPushed(blobs)
        #expect(sync.pendingBlobs().isEmpty)
    }

    @Test func two_devices_edit_same_exercise_both_notes_survive() throws {
        let (store, _, _) = makeStore()
        try store.save(note(text: "A", at: 1))
        #expect(store.merge([note(text: "B", at: 2)]))
        #expect(Set(store.notes(for: key).map(\.text)) == ["A", "B"])
    }

    @Test func same_note_edited_newest_wins() throws {
        let (store, _, _) = makeStore()
        let id = UUID()
        try store.save(note(id: id, text: "velho", at: 1))
        #expect(store.merge([note(id: id, text: "novo", at: 5)]))
        #expect(!store.merge([note(id: id, text: "antigo", at: 3)]))
        #expect(store.notes(for: key).map(\.text) == ["novo"])
    }

    @Test func deleted_note_hidden_but_kept_for_merge() throws {
        let (store, sync, _) = makeStore()
        let saved = note(at: 1)
        try store.save(saved)
        try store.delete(saved.id, at: base.addingTimeInterval(9))
        #expect(store.notes(for: key).isEmpty)
        #expect(store.allActive().isEmpty)
        #expect(store.all().first?.deleted == true)
        #expect(sync.pendingBlobs().count == 1)
        #expect(!store.merge([note(id: saved.id, at: 5)]))
        #expect(store.notes(for: key).isEmpty)
    }

    @Test func mfit_and_catalog_keys_share_notes_when_mapped() throws {
        let (store, _, _) = makeStore()
        try store.save(note())
        let mapped = ExerciseMediaCatalog(data: Data(#"{"midias":{},"mfit":{"agachamento goblet":"SQUAT/GOBLET_SQUAT"},"padroes":{}}"#.utf8))
        let resolved = mapped.key(forMFITName: "Agachamento Goblet", category: nil)
        #expect(resolved == key)
        #expect(store.notes(for: resolved).count == 1)
    }

    @Test func corrupt_file_that_cannot_be_moved_is_not_overwritten() throws {
        let (original, _, url) = makeStore()
        let garbage = Data("nao e json".utf8)
        try garbage.write(to: url)
        var store = original
        store.moveAside = { _, _ in throw CocoaError(.fileWriteNoPermission) }
        #expect(throws: (any Error).self) { try store.save(note()) }
        #expect(!store.merge([note()]))
        #expect(try Data(contentsOf: url) == garbage)
    }

    @Test func apply_rejects_invalid_blob() {
        let (_, sync, _) = makeStore()
        #expect(!sync.apply(RemoteBlob(id: "exerciseNotes", data: Data("x".utf8), updatedAt: base)))
    }

    private func accept(_ blobs: [RemoteBlob], into server: inout RemoteBlob?) {
        for blob in blobs where server == nil || RemoteTimestamp.milliseconds(blob.updatedAt) > RemoteTimestamp.milliseconds(server!.updatedAt) {
            server = blob
        }
    }

    @Test func union_after_pull_is_pushed_with_newer_stamp() throws {
        let (storeA, syncA, _) = makeStore()
        let (storeB, syncB, _) = makeStore()
        var server: RemoteBlob?
        try storeA.save(note(at: 5))
        let pushedA = syncA.pendingBlobs()
        accept(pushedA, into: &server)
        syncA.markBlobsPushed(pushedA)
        try storeB.save(note(text: "B", at: 3))
        let pushedB = syncB.pendingBlobs()
        accept(pushedB, into: &server)
        syncB.markBlobsPushed(pushedB)
        #expect(server?.updatedAt == pushedA[0].updatedAt)
        #expect(syncB.apply(server!))
        let next = syncB.pendingBlobs()
        #expect(next.count == 1)
        #expect(next[0].updatedAt > pushedA[0].updatedAt)
        #expect(try JSONDecoder().decode([ExerciseNote].self, from: next[0].data).count == 2)
        accept(next, into: &server)
        #expect(try JSONDecoder().decode([ExerciseNote].self, from: server!.data).count == 2)
    }

    @Test func echo_of_remote_does_not_repush() throws {
        let (storeA, syncA, _) = makeStore()
        let (_, syncB, _) = makeStore()
        try storeA.save(note(at: 5))
        let remote = syncA.pendingBlobs()
        #expect(syncB.apply(remote[0]))
        #expect(syncB.pendingBlobs().isEmpty)
    }

    @Test func save_between_pending_and_mark_is_pushed() throws {
        let (store, sync, _) = makeStore()
        try store.save(note(at: 5))
        let first = sync.pendingBlobs()
        try store.save(note(text: "Y", at: 5))
        sync.markBlobsPushed(first)
        let next = sync.pendingBlobs()
        #expect(next.count == 1)
        #expect(try JSONDecoder().decode([ExerciseNote].self, from: next[0].data).count == 2)
    }

    @Test func save_after_future_remote_stamp_is_pushed() throws {
        let (storeA, syncA, _) = makeStore()
        let (storeB, syncB, _) = makeStore()
        try storeA.save(note(at: 5))
        try storeB.save(note(text: "Y", at: 5))
        #expect(syncB.apply(syncA.pendingBlobs()[0]))
        let pushed = syncB.pendingBlobs()
        syncB.markBlobsPushed(pushed)
        #expect(syncB.pendingBlobs().isEmpty)
        try storeB.save(note(text: "Z", at: 0))
        let next = syncB.pendingBlobs()
        #expect(next.count == 1)
        #expect(next[0].updatedAt > pushed[0].updatedAt)
    }
}
