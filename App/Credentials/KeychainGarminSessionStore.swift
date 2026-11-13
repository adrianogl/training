import Foundation
import GarminAPI

struct KeychainGarminSessionStore: GarminSessionStore {
    let keychain: any APIKeyStore

    func load() throws -> GarminAccountSession? {
        guard let text = try keychain.read(), let data = text.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(GarminAccountSession.self, from: data)
    }

    func save(_ session: GarminAccountSession) throws {
        let data = try JSONEncoder().encode(session)
        try keychain.save(String(decoding: data, as: UTF8.self))
    }

    func delete() throws {
        try keychain.delete()
    }
}
