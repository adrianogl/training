import Foundation
import Insights
import RemoteSync
import Testing
import TrainingCore
@testable import trAIning

@Suite struct ClaudeSyncTests {
    private func defaults() -> UserDefaults { UserDefaults(suiteName: "claude-sync-\(UUID())")! }

    private func envelope(_ texto: String) -> ClaudeContextEnvelope {
        let input = ClaudeContextInput(
            today: Day(iso: "2026-11-18")!, first: Day(iso: "2026-11-19")!, last: Day(iso: "2026-12-12")!, trainerSessions: [], mfit: [:],
            runs: [:], readiness: [:], pain: [], loads: [:], race: nil
        )
        return ClaudeContextEnvelope(atualizado: "2026-11-18T10:00:00Z", texto: texto, contexto: ClaudeContextBuilder.payload(input))
    }

    @Test func publishesOnlyWhenTheContextChanges() {
        let mailbox = ClaudeMailbox(defaults: defaults())
        #expect(mailbox.publish(envelope("A"), now: Date(timeIntervalSince1970: 1)))
        #expect(!mailbox.publish(envelope("A"), now: Date(timeIntervalSince1970: 2)))
        #expect(mailbox.publish(envelope("B"), now: Date(timeIntervalSince1970: 3)))
        #expect(mailbox.outbox()?.stamp == Date(timeIntervalSince1970: 3))
    }

    @Test func contextStorePushesUntilMarked() throws {
        let store = defaults()
        ClaudeMailbox(defaults: store).publish(envelope("A"), now: Date(timeIntervalSince1970: 10))
        let sync = ClaudeContextSyncStore(defaults: store)
        let pending = sync.pendingBlobs()
        #expect(pending.map(\.id) == ["strengthContext"])
        let body = try JSONSerialization.jsonObject(with: try #require(pending.first).data) as? [String: Any]
        #expect(body?["texto"] as? String == "A")
        #expect((body?["contexto"] as? [String: Any])?["dias_do_treinador"] != nil)
        sync.markBlobsPushed(pending)
        #expect(sync.pendingBlobs().isEmpty)
    }

    @Test func inboxKeepsTheNewestAndTracksSeen() {
        let store = defaults()
        let sync = ClaudeInboxSyncStore(defaults: store)
        let blob = { (json: String, stamp: Double) in
            RemoteBlob(id: "strengthClaude", data: Data(#"{"salvoEm":"x","json":"\#(json)"}"#.utf8), updatedAt: Date(timeIntervalSince1970: stamp))
        }
        #expect(sync.apply(blob("primeiro", 100)))
        #expect(!sync.apply(blob("velho", 50)))
        let mailbox = ClaudeMailbox(defaults: store)
        #expect(mailbox.unseen()?.json == "primeiro")
        mailbox.markSeen(mailbox.unseen()!)
        #expect(mailbox.unseen() == nil)
        #expect(sync.apply(blob("segundo", 200)))
        #expect(mailbox.unseen()?.json == "segundo")
        #expect(!sync.handles("strengthContext"))
        #expect(ClaudeContextSyncStore(defaults: store).handles("strengthContext"))
    }
}
