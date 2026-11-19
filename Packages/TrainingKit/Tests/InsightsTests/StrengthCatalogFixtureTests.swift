import Foundation
import Testing
@testable import Insights

@Suite struct StrengthCatalogFixtureTests {
    private static let fixture = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "server/test/fixtures/strength-catalog.json")

    private static func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(StrengthCatalog.all.map(StrengthCatalog.contextLine))
    }

    @Test func serverFixtureMatchesTheCatalog() throws {
        let data = try Self.encoded()
        if ProcessInfo.processInfo.environment["WRITE_FIXTURES"] == "1" {
            try data.write(to: Self.fixture)
        }
        #expect(try Data(contentsOf: Self.fixture) == data, "rode com WRITE_FIXTURES=1 para atualizar server/test/fixtures/strength-catalog.json")
    }
}
