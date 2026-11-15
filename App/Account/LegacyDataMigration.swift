import Foundation

struct LegacyDataMigration: Sendable {
    private typealias C = AccountScopeConstants

    nonisolated(unsafe) let defaults: UserDefaults
    let domain: String
    let supportFolder: URL
    let cachesFolder: URL
    let keychain: @Sendable (String) -> any APIKeyStore

    static let live = LegacyDataMigration(
        defaults: .standard,
        domain: Bundle.main.bundleIdentifier ?? "",
        supportFolder: .applicationSupportDirectory,
        cachesFolder: .cachesDirectory,
        keychain: { KeychainKeyStore(account: $0) }
    )

    var owner: String? { defaults.string(forKey: C.migratedOwnerDefaultsKey) }

    func legacyKey(_ account: String) -> String? {
        guard owner == nil, let key = (try? keychain(account).read()) ?? nil, !key.isEmpty else { return nil }
        return key
    }

    @discardableResult
    func run(into scope: AccountScope) -> Bool {
        guard owner == nil else { return false }
        scope.prepare()
        var complete = move(C.legacySupportItems, from: supportFolder, to: scope.supportFolder)
        complete = move(C.legacyCacheItems, from: cachesFolder, to: scope.cachesFolder) && complete
        complete = C.keychainAccounts.map { moveKey($0, to: scope) }.allSatisfy { $0 } && complete
        moveDefaults(to: scope.defaults)
        guard complete else { return false }
        defaults.set(scope.id, forKey: C.migratedOwnerDefaultsKey)
        return true
    }

    private func move(_ names: [String], from source: URL, to destination: URL) -> Bool {
        let files = FileManager.default
        var complete = true
        for name in names {
            let from = source.appending(path: name)
            let to = destination.appending(path: name)
            guard files.fileExists(atPath: from.path) else { continue }
            if files.fileExists(atPath: to.path) { continue }
            do {
                try files.moveItem(at: from, to: to)
            } catch {
                complete = false
            }
        }
        return complete
    }

    private func moveKey(_ account: String, to scope: AccountScope) -> Bool {
        let legacy = keychain(account)
        guard let value = (try? legacy.read()) ?? nil else { return true }
        let scoped = scope.keyStore(account)
        do {
            if ((try? scoped.read()) ?? nil) == nil { try scoped.save(value) }
            try legacy.delete()
            return true
        } catch {
            return false
        }
    }

    private func moveDefaults(to scoped: UserDefaults) {
        let stored = defaults.persistentDomain(forName: domain) ?? [:]
        let keys = stored.keys.filter { key in
            C.scopedDefaultsKeys.contains(key) || C.scopedDefaultsPrefixes.contains { key.hasPrefix($0) }
        }
        for key in keys {
            if scoped.object(forKey: key) == nil, let value = stored[key] { scoped.set(value, forKey: key) }
            defaults.removeObject(forKey: key)
        }
    }
}
