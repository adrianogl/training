import Foundation
import Testing
@testable import trAIning

@Suite struct AppBuildInfoTests {
    @Test func versionLineJoinsVersionBuildAndCommit() {
        let info = AppBuildInfo(version: "0.1.0", build: "1", commit: "c9632304", builtAt: nil)
        #expect(info.versionLine == "trAIning 0.1.0 (1) · c9632304")
        #expect(info.builtLine() == nil)
    }

    @Test func builtLineUsesTheLocalTime() throws {
        let built = try Date("2026-11-18T14:42:00Z", strategy: .iso8601)
        let info = AppBuildInfo(version: "0.1.0", build: "1", commit: nil, builtAt: built)
        #expect(info.versionLine == "trAIning 0.1.0 (1)")
        #expect(info.builtLine(timeZone: TimeZone(identifier: "America/Sao_Paulo")!) == "gerado em 18/11 às 11:42")
    }
}
