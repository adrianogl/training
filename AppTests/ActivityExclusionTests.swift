import Foundation
import Testing
@testable import trAIning

@Suite struct ActivityExclusionTests {
    private func store() -> ActivityExclusionStore {
        ActivityExclusionStore(url: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".json"))
    }

    @Test func deletedAndOwnIdsAreKept() {
        let store = store()
        store.markDeleted(10)
        store.markOwn(20)
        store.markDeleted(10)
        #expect(store.deletedIds == [10])
        #expect(store.isOwn(20))
        #expect(!store.isOwn(10))
    }

    @Test func mergeJoinsBothDevices() {
        let phone = ActivityExclusions(deleted: [1, 3], own: [3])
        let pad = ActivityExclusions(deleted: [2, 3], own: [])
        #expect(phone.merged(with: pad) == ActivityExclusions(deleted: [1, 2, 3], own: [3]))
    }

    @Test func syncStoreAppliesRemoteDeletions() throws {
        let store = store()
        store.markDeleted(1)
        let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
        let sync = ActivityExclusionSyncStore(store: store, defaults: defaults)
        let remote = try JSONEncoder().encode(ActivityExclusions(deleted: [2], own: [2]))
        #expect(sync.apply(.init(id: ActivityExclusionConstants.blobId, data: remote, updatedAt: .now)))
        #expect(store.deletedIds == [1, 2])
        #expect(store.isOwn(2))
        #expect(!sync.pendingBlobs().isEmpty)
    }
}
