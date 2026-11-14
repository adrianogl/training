import Foundation
import Testing
@testable import trAIning

@Suite struct SyncStatusPillTextTests {
    @Test func idleShowsNothing() {
        #expect(SyncStatusPillText.content(for: .idle, showsFinished: true) == nil)
    }

    @Test func runningShowsPercentOnceProgressStarts() {
        let started = SyncStatusPillText.content(for: .running(progress: 0.42), showsFinished: false)
        #expect(started?.kind == .syncing)
        #expect(started?.text == "Sincronizando · 42%")

        let beginning = SyncStatusPillText.content(for: .running(progress: 0), showsFinished: false)
        #expect(beginning?.text == "Sincronizando")
    }

    @Test func runningClampsProgress() {
        #expect(SyncStatusPillText.content(for: .running(progress: 1.4), showsFinished: false)?.text == "Sincronizando · 100%")
    }

    @Test func finishedShowsOnlyWhileTheWindowIsOpen() {
        let status = SyncStatus.finished(.now)
        #expect(SyncStatusPillText.content(for: status, showsFinished: true)?.text == "Atualizado agora")
        #expect(SyncStatusPillText.content(for: status, showsFinished: true)?.kind == .updated)
        #expect(SyncStatusPillText.content(for: status, showsFinished: false) == nil)
    }

    @Test func failureInvitesRetry() {
        let content = SyncStatusPillText.content(for: .failed(.missingKey), showsFinished: false)
        #expect(content?.kind == .failed)
        #expect(content?.text == "Não sincronizou · tocar para tentar de novo")
    }
}
