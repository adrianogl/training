protocol APIKeyStore: Sendable {
    func read() throws -> String?
    func save(_ key: String) throws
    func delete() throws
}
