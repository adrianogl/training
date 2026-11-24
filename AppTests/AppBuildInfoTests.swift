import Foundation
import Testing
@testable import trAIning

@Suite struct AppBuildInfoTests {
    @Test func footerLineShowsTheCommitWithoutTheVersion() {
        let info = AppBuildInfo(version: "0.1.0", build: "1", commit: "c9632304", builtAt: nil)
        #expect(info.footerLine() == "commit c9632304")
        #expect(info.builtLine() == nil)
    }

    @Test func builtLineUsesTheLocalTime() throws {
        let built = try Date("2026-11-18T14:42:00Z", strategy: .iso8601)
        let info = AppBuildInfo(version: "0.1.0", build: "1", commit: nil, builtAt: built)
        let saoPaulo = TimeZone(identifier: "America/Sao_Paulo")!
        #expect(info.builtLine(timeZone: saoPaulo) == "gerado em 18/11 às 11:42")
        #expect(info.footerLine(timeZone: saoPaulo) == "gerado em 18/11 às 11:42")
    }

    @Test func footerLineJoinsCommitAndBuildTime() throws {
        let built = try Date("2026-11-18T14:42:00Z", strategy: .iso8601)
        let info = AppBuildInfo(version: "0.1.0", build: "1", commit: "c9632304", builtAt: built)
        #expect(info.footerLine(timeZone: TimeZone(identifier: "America/Sao_Paulo")!) == "commit c9632304 · gerado em 18/11 às 11:42")
    }
}
