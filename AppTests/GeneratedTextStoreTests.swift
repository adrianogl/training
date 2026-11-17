import Foundation
import RemoteSync
import Testing
@testable import trAIning

@Suite struct GeneratedTextStoreTests {
    private static let stamp = Date(timeIntervalSince1970: 1_794_864_600)

    private static func store() -> GeneratedTextStore {
        GeneratedTextStore(defaults: UserDefaults(suiteName: "generated-\(UUID().uuidString)")!, now: { stamp })
    }

    @Test func savedTextIsPendingUntilPushed() {
        let store = Self.store()
        store.save("Treino bom a 4:53/km.", for: ["fato"])

        let pending = store.pendingNarratives()
        store.markNarrativesPushed(pending)

        #expect(pending == [RemoteNarrative(id: GeneratedTextStore.id(for: ["fato"]), text: "Treino bom a 4:53/km.", updatedAt: Self.stamp)])
        #expect(store.pendingNarratives().isEmpty)
        #expect(store.text(for: ["fato"]) == "Treino bom a 4:53/km.")
    }

    @Test func textRewrittenDuringPushStaysPending() {
        let store = Self.store()
        store.save("Primeiro.", for: ["fato"])
        let pending = store.pendingNarratives()
        store.save("Segundo.", for: ["fato"])

        store.markNarrativesPushed(pending)

        #expect(store.pendingNarratives().map(\.text) == ["Segundo."])
    }

    @Test func textFromAnotherDeviceIsReadWithoutBeingPushedBack() {
        let store = Self.store()
        let id = GeneratedTextStore.id(for: ["fato"])

        _ = store.apply(RemoteNarrative(id: id, text: "Do iPhone.", updatedAt: Self.stamp))

        #expect(store.text(for: ["fato"]) == "Do iPhone.")
        #expect(store.narrativeUpdatedAt(id: id) == Self.stamp)
        #expect(store.pendingNarratives().isEmpty)
    }
}
