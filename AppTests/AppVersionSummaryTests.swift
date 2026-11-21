import Testing
@testable import trAIning

@Suite struct AppVersionSummaryTests {
    private let release = AppRelease(
        versao: "1.31.1", build: 44, versao_app: "1.31.0", notas: ["Recorde"],
        historico: [
            AppReleaseNotes(versao: "1.31.0", notas: ["Recorde", "Meta"]),
            AppReleaseNotes(versao: "1.30.0", notas: ["Cantos"]),
        ]
    )

    @Test func upToDateShowsNotesOfInstalledVersion() {
        let summary = AppVersion.summary(release: release, installed: "1.31.0")
        #expect(summary.installed == "1.31.0")
        #expect(summary.latest == "1.31.0")
        #expect(!summary.hasUpdate)
        #expect(summary.notesVersion == "1.31.0")
        #expect(summary.notes == ["Recorde", "Meta"])
    }

    @Test func newerVersionShowsItsNotes() {
        let summary = AppVersion.summary(release: release, installed: "1.30.0")
        #expect(summary.latest == "1.31.0")
        #expect(summary.hasUpdate)
        #expect(summary.notesVersion == "1.31.0")
        #expect(summary.notes == ["Recorde", "Meta"])
    }

    @Test func installedWithoutNotesFallsBackToPreviousWithNotes() {
        let summary = AppVersion.summary(release: release, installed: "1.30.2")
        #expect(summary.notesVersion == "1.31.0")
        let older = AppVersion.summary(release: AppRelease(versao: "1.30.0", build: 42, versao_app: "1.30.0", notas: ["Cantos"]), installed: "1.30.1")
        #expect(older.notesVersion == "1.30.0")
        #expect(older.notes == ["Cantos"])
        #expect(!older.hasUpdate)
    }

    @Test func withoutReleaseShowsOnlyInstalled() {
        let summary = AppVersion.summary(release: nil, installed: "1.31.0")
        #expect(summary.latest == nil)
        #expect(summary.notes.isEmpty)
        #expect(!summary.hasUpdate)
    }
}
