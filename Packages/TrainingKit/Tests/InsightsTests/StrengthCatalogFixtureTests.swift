import Foundation
import Testing
@testable import Insights

@Suite struct StrengthCatalogFixtureTests {
    private static let fixture = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "server/test/fixtures/strength-catalog.json")

    private static func encoded() throws -> Data {
        let rows: [[String: AnyCodableValue]] = StrengthCatalog.all.map {
            [
                "id": .text($0.id), "nome": .text($0.name), "padrao": .text($0.pattern.rawValue), "equipamento": .text($0.equipment.rawValue),
                "regioes": .list($0.loads.map(\.rawValue).sorted()), "focos": .list($0.focus.map(\.rawValue).sorted()),
                "unilateral": .flag($0.unilateral), "isometria": .flag($0.timed),
            ]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(rows)
    }

    @Test func serverFixtureMatchesTheCatalog() throws {
        let data = try Self.encoded()
        if ProcessInfo.processInfo.environment["WRITE_FIXTURES"] == "1" {
            try data.write(to: Self.fixture)
        }
        #expect(try Data(contentsOf: Self.fixture) == data, "rode com WRITE_FIXTURES=1 para atualizar server/test/fixtures/strength-catalog.json")
    }
}

private enum AnyCodableValue: Encodable {
    case text(String), list([String]), flag(Bool)

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .list(let value): try container.encode(value)
        case .flag(let value): try container.encode(value)
        }
    }
}
