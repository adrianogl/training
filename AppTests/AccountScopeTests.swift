import Foundation
import GarminAPI
import RemoteSync
import Storage
import SwiftData
import Synchronization
import Testing
@testable import trAIning

private final class FakeKeychain: Sendable {
    private let items = Mutex<[String: String]>([:])

    var accounts: Set<String> { Set(items.withLock { $0.keys }) }

    func store(_ account: String) -> any APIKeyStore { Item(account: account, keychain: self) }

    func value(_ account: String) -> String? { items.withLock { $0[account] } }

    func set(_ value: String?, for account: String) { items.withLock { $0[account] = value } }

    private struct Item: APIKeyStore {
        let account: String
        let keychain: FakeKeychain

        func read() throws -> String? { keychain.value(account) }
        func save(_ key: String) throws { keychain.set(key, for: account) }
        func delete() throws { keychain.set(nil, for: account) }
    }
}

private final class ScriptedTransport: HTTPTransport {
    private let replies = Mutex<[(Int, String)]>([])

    func reply(_ status: Int, _ body: String = "") { replies.withLock { $0.append((status, body)) } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, body) = replies.withLock { $0.isEmpty ? (500, "") : $0.removeFirst() }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private struct Sandbox {
    let root = FileManager.default.temporaryDirectory.appending(path: "AccountScopeTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    let keychain = FakeKeychain()

    var support: URL { root.appending(path: "Support", directoryHint: .isDirectory) }
    var caches: URL { root.appending(path: "Caches", directoryHint: .isDirectory) }

    func scope(_ email: String) -> AccountScope {
        let keychain = keychain
        return AccountScope(id: AccountScope.id(email: email) + "-" + root.lastPathComponent, supportRoot: support, cachesRoot: caches, keychain: { keychain.store($0) })
    }

    func migration(defaults: UserDefaults, domain: String) -> LegacyDataMigration {
        let keychain = keychain
        return LegacyDataMigration(defaults: defaults, domain: domain, supportFolder: support, cachesFolder: caches, keychain: { keychain.store($0) })
    }

    func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func read(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
    }

    static func legacyDefaults() -> (UserDefaults, String) {
        let name = "AccountScopeTests.legacy.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }
}

@MainActor
@Suite struct AccountScopeTests {
    @Test func scopeIdComesFromNormalizedEmail() {
        #expect(AccountScope.id(email: " Atleta@Exemplo.com ") == AccountScope.id(email: "atleta@exemplo.com"))
        #expect(AccountScope.id(email: "atleta@exemplo.com") != AccountScope.id(email: "outra@exemplo.com"))
        #expect(AccountScope.id(email: "atleta@exemplo.com").count == AccountScopeConstants.idByteCount * 2)
    }

    @Test func accountsDoNotSeeEachOthersData() throws {
        let sandbox = Sandbox()
        let first = sandbox.scope("a@exemplo.com")
        let second = sandbox.scope("b@exemplo.com")
        first.prepare()
        second.prepare()

        first.defaults.set(42, forKey: AppConstants.weeklyGoalDefaultsKey)
        try first.keyStore(AppConstants.keychainAccount).save("chave-garmin-a")
        try sandbox.write("plano", to: first.trainerURL)
        let firstContainer = try TrainingSchema.container(url: first.storeURL)
        firstContainer.mainContext.insert(RaceDecisionRecord(activityId: 1, decision: .race))
        try firstContainer.mainContext.save()

        let secondContainer = try TrainingSchema.container(url: second.storeURL)
        #expect(second.defaults.object(forKey: AppConstants.weeklyGoalDefaultsKey) == nil)
        #expect(try second.keyStore(AppConstants.keychainAccount).read() == nil)
        #expect(!FileManager.default.fileExists(atPath: second.trainerURL.path))
        #expect(try secondContainer.mainContext.fetchCount(FetchDescriptor<RaceDecisionRecord>()) == 0)
        #expect(first.storeURL != second.storeURL)
        #expect(first.snapshotsFolder != second.snapshotsFolder)
        #expect(first.suiteName != second.suiteName)
    }

    @Test func eraseRemovesOnlyItsOwnScope() throws {
        let sandbox = Sandbox()
        let first = sandbox.scope("a@exemplo.com")
        let second = sandbox.scope("b@exemplo.com")
        for scope in [first, second] {
            scope.prepare()
            scope.defaults.set("valor", forKey: StravaConstants.ledgerDefaultsKey)
            try sandbox.write("plano", to: scope.trainerURL)
            try sandbox.write("{}", to: scope.snapshotsFolder.appending(path: "today.json"))
            for account in AccountScopeConstants.keychainAccounts { try scope.keyStore(account).save("segredo") }
        }

        first.erase()

        #expect(!FileManager.default.fileExists(atPath: first.supportFolder.path))
        #expect(!FileManager.default.fileExists(atPath: first.cachesFolder.path))
        #expect(UserDefaults(suiteName: first.suiteName)?.object(forKey: StravaConstants.ledgerDefaultsKey) == nil)
        for account in AccountScopeConstants.keychainAccounts {
            #expect(try first.keyStore(account).read() == nil)
            #expect(try second.keyStore(account).read() == "segredo")
        }
        #expect(sandbox.read(second.trainerURL) == "plano")
        #expect(FileManager.default.fileExists(atPath: second.snapshotsFolder.appending(path: "today.json").path))
        #expect(second.defaults.string(forKey: StravaConstants.ledgerDefaultsKey) == "valor")
    }

    @Test func migrationMovesLegacyDataIntoTheFirstScope() throws {
        let sandbox = Sandbox()
        let (legacy, domain) = Sandbox.legacyDefaults()
        let support = sandbox.support
        try sandbox.write("banco", to: support.appending(path: AppConstants.storeFileName))
        try sandbox.write("wal", to: support.appending(path: AppConstants.storeFileName + "-wal"))
        try sandbox.write("rota", to: support.appending(path: ".store_SUPPORT/_EXTERNAL_DATA/rota"))
        try sandbox.write("plano", to: support.appending(path: TrainerConstants.storeFileName))
        try sandbox.write("[]", to: support.appending(path: WorkoutChatConstants.raceFolderName).appending(path: "1.json"))
        try sandbox.write("{}", to: sandbox.caches.appending(path: ScreenSnapshotConstants.directoryName).appending(path: "today.json"))
        try sandbox.write("fica", to: support.appending(path: "outro.txt"))
        sandbox.keychain.set("chave-garmin", for: AppConstants.keychainAccount)
        sandbox.keychain.set("chave-sync", for: AppConstants.remoteSyncKeychainAccount)
        sandbox.keychain.set("sessao", for: AccountConstants.keychainAccount)
        legacy.set(30, forKey: AppConstants.weeklyGoalDefaultsKey)
        legacy.set(true, forKey: "remoteSync.plainPayloadsPushed")
        legacy.set("texto", forKey: GeneratedTextConstants.keyPrefix + "abc")
        legacy.set("dark", forKey: AppConstants.appearanceDefaultsKey)
        legacy.set(true, forKey: BackgroundConstants.permissionRequestedDefaultsKey)
        let owner = sandbox.scope("dono@exemplo.com")
        let migration = sandbox.migration(defaults: legacy, domain: domain)

        #expect(migration.legacyKey(AppConstants.remoteSyncKeychainAccount) == "chave-sync")
        #expect(migration.run(into: owner))

        #expect(sandbox.read(owner.storeURL) == "banco")
        #expect(sandbox.read(owner.supportFolder.appending(path: AppConstants.storeFileName + "-wal")) == "wal")
        #expect(sandbox.read(owner.supportFolder.appending(path: ".store_SUPPORT/_EXTERNAL_DATA/rota")) == "rota")
        #expect(sandbox.read(owner.trainerURL) == "plano")
        #expect(sandbox.read(owner.supportFolder.appending(path: WorkoutChatConstants.raceFolderName).appending(path: "1.json")) == "[]")
        #expect(sandbox.read(owner.snapshotsFolder.appending(path: "today.json")) == "{}")
        #expect(!FileManager.default.fileExists(atPath: support.appending(path: AppConstants.storeFileName).path))
        #expect(sandbox.read(support.appending(path: "outro.txt")) == "fica")
        #expect(try owner.keyStore(AppConstants.keychainAccount).read() == "chave-garmin")
        #expect(try owner.keyStore(AppConstants.remoteSyncKeychainAccount).read() == "chave-sync")
        #expect(sandbox.keychain.value(AppConstants.keychainAccount) == nil)
        #expect(sandbox.keychain.value(AccountConstants.keychainAccount) == "sessao")
        #expect(owner.defaults.integer(forKey: AppConstants.weeklyGoalDefaultsKey) == 30)
        #expect(owner.defaults.bool(forKey: "remoteSync.plainPayloadsPushed"))
        #expect(owner.defaults.string(forKey: GeneratedTextConstants.keyPrefix + "abc") == "texto")
        #expect(legacy.object(forKey: AppConstants.weeklyGoalDefaultsKey) == nil)
        #expect(legacy.string(forKey: AppConstants.appearanceDefaultsKey) == "dark")
        #expect(legacy.bool(forKey: BackgroundConstants.permissionRequestedDefaultsKey))
        #expect(owner.defaults.object(forKey: AppConstants.appearanceDefaultsKey) == nil)
        #expect(migration.owner == owner.id)
        #expect(migration.legacyKey(AppConstants.remoteSyncKeychainAccount) == nil)
    }

    @Test func migrationRunsOnlyOnce() throws {
        let sandbox = Sandbox()
        let (legacy, domain) = Sandbox.legacyDefaults()
        let migration = sandbox.migration(defaults: legacy, domain: domain)
        let owner = sandbox.scope("dono@exemplo.com")
        #expect(migration.run(into: owner))

        try sandbox.write("novo", to: sandbox.support.appending(path: TrainerConstants.storeFileName))
        legacy.set(10, forKey: AppConstants.weeklyGoalDefaultsKey)
        let other = sandbox.scope("outra@exemplo.com")

        #expect(!migration.run(into: other))
        #expect(!migration.run(into: owner))
        #expect(!FileManager.default.fileExists(atPath: other.trainerURL.path))
        #expect(!FileManager.default.fileExists(atPath: owner.trainerURL.path))
        #expect(other.defaults.object(forKey: AppConstants.weeklyGoalDefaultsKey) == nil)
        #expect(migration.owner == owner.id)
    }

    @Test func interruptedMigrationKeepsWhatAlreadyMoved() throws {
        let sandbox = Sandbox()
        let (legacy, domain) = Sandbox.legacyDefaults()
        let owner = sandbox.scope("dono@exemplo.com")
        owner.prepare()
        try sandbox.write("movido", to: owner.trainerURL)
        try owner.keyStore(AppConstants.watchTokenKeychainAccount).save("token-novo")
        owner.defaults.set(50, forKey: AppConstants.weeklyGoalDefaultsKey)
        try sandbox.write("antigo", to: sandbox.support.appending(path: AppConstants.storeFileName))
        sandbox.keychain.set("token-antigo", for: AppConstants.watchTokenKeychainAccount)
        legacy.set(20, forKey: AppConstants.weeklyGoalDefaultsKey)

        #expect(sandbox.migration(defaults: legacy, domain: domain).run(into: owner))

        #expect(sandbox.read(owner.trainerURL) == "movido")
        #expect(sandbox.read(owner.storeURL) == "antigo")
        #expect(try owner.keyStore(AppConstants.watchTokenKeychainAccount).read() == "token-novo")
        #expect(sandbox.keychain.value(AppConstants.watchTokenKeychainAccount) == nil)
        #expect(owner.defaults.integer(forKey: AppConstants.weeklyGoalDefaultsKey) == 50)
        #expect(legacy.object(forKey: AppConstants.weeklyGoalDefaultsKey) == nil)
    }
}

@MainActor private final class StopCounter {
    var count = 0
}

@MainActor
@Suite struct AppSessionTests {
    private static let baseURL = URL(string: "https://sync.example.test")!

    private static func session(sandbox: Sandbox, transport: ScriptedTransport, migration: LegacyDataMigration? = nil) -> (AppSession, StopCounter) {
        let account = AccountModel(
            store: MemoryKeyStore(), transport: transport, baseURL: baseURL,
            defaults: UserDefaults(suiteName: "AppSessionTests.\(UUID().uuidString)")!, device: "iPhone"
        )
        let stops = StopCounter()
        let session = AppSession(
            account: account,
            makeScope: { sandbox.scope($0.email) },
            makeModel: { scope, account in
                AppModel(
                    container: try! TrainingSchema.container(inMemory: true),
                    scope: scope,
                    account: account,
                    keyStore: MemoryKeyStore(),
                    transport: transport,
                    remoteKeyStore: MemoryKeyStore(),
                    watchTokenStore: MemoryKeyStore(),
                    garminSessionStore: MemoryKeyStore(),
                    remoteDefaults: scope.defaults,
                    trainerStore: TrainerStore(url: scope.trainerURL, defaults: scope.defaults),
                    snapshots: ScreenSnapshotStore(directory: scope.snapshotsFolder),
                    remoteBaseURL: baseURL,
                    autoSyncEnabled: false,
                    notifier: MorningNotifier(defaults: scope.defaults)
                )
            },
            migration: migration,
            publish: { _ in },
            startBackgroundWork: { _ in },
            stopBackgroundWork: { stops.count += 1 }
        )
        return (session, stops)
    }

    private static func login(_ session: AppSession, _ transport: ScriptedTransport, email: String) async {
        transport.reply(200, #"{"token":"sessao-\#(email)","user":{"email":"\#(email)","name":"Atleta","emailVerified":true}}"#)
        _ = await session.account.login(email: email, password: "senha-longa-123")
    }

    @Test func signOutKeepsDataAndReturningAccountSeesItAgain() async throws {
        let sandbox = Sandbox()
        let transport = ScriptedTransport()
        let (session, stops) = Self.session(sandbox: sandbox, transport: transport)
        #expect(session.model == nil)

        await Self.login(session, transport, email: "a@exemplo.com")
        let first = try #require(session.model)
        first.scope.defaults.set(40, forKey: AppConstants.weeklyGoalDefaultsKey)
        try first.scope.keyStore(AppConstants.keychainAccount).save("chave-a")

        transport.reply(204)
        await session.account.signOut()
        #expect(session.model == nil)
        #expect(stops.count == 1)
        #expect(first.scope.defaults.integer(forKey: AppConstants.weeklyGoalDefaultsKey) == 40)

        await Self.login(session, transport, email: "b@exemplo.com")
        let second = try #require(session.model)
        #expect(second.scope.id != first.scope.id)
        #expect(second.scope.defaults.object(forKey: AppConstants.weeklyGoalDefaultsKey) == nil)
        #expect(try second.scope.keyStore(AppConstants.keychainAccount).read() == nil)

        transport.reply(204)
        await session.account.signOut()
        await Self.login(session, transport, email: "a@exemplo.com")
        let again = try #require(session.model)
        #expect(again.scope.id == first.scope.id)
        #expect(again.scope.defaults.integer(forKey: AppConstants.weeklyGoalDefaultsKey) == 40)
        #expect(try again.scope.keyStore(AppConstants.keychainAccount).read() == "chave-a")
    }

    @Test func deletingAccountErasesOnlyItsScope() async throws {
        let sandbox = Sandbox()
        let transport = ScriptedTransport()
        let (session, _) = Self.session(sandbox: sandbox, transport: transport)

        await Self.login(session, transport, email: "b@exemplo.com")
        let other = try #require(session.model).scope
        other.defaults.set(15, forKey: AppConstants.weeklyGoalDefaultsKey)
        transport.reply(204)
        await session.account.signOut()

        await Self.login(session, transport, email: "a@exemplo.com")
        let deleted = try #require(session.model).scope
        deleted.defaults.set(40, forKey: AppConstants.weeklyGoalDefaultsKey)
        try sandbox.write("plano", to: deleted.trainerURL)
        try deleted.keyStore(AppConstants.keychainAccount).save("chave-a")
        transport.reply(204)
        #expect(await session.account.deleteAccount())

        #expect(session.model == nil)
        #expect(!FileManager.default.fileExists(atPath: deleted.supportFolder.path))
        #expect(try deleted.keyStore(AppConstants.keychainAccount).read() == nil)
        #expect(UserDefaults(suiteName: deleted.suiteName)?.object(forKey: AppConstants.weeklyGoalDefaultsKey) == nil)
        #expect(other.defaults.integer(forKey: AppConstants.weeklyGoalDefaultsKey) == 15)
        #expect(FileManager.default.fileExists(atPath: other.supportFolder.path))
    }

    @Test func firstAccountToSignInReceivesLegacyData() async throws {
        let sandbox = Sandbox()
        let (legacy, domain) = Sandbox.legacyDefaults()
        legacy.set(25, forKey: AppConstants.weeklyGoalDefaultsKey)
        sandbox.keychain.set("chave-garmin", for: AppConstants.keychainAccount)
        let transport = ScriptedTransport()
        let (session, _) = Self.session(sandbox: sandbox, transport: transport, migration: sandbox.migration(defaults: legacy, domain: domain))

        await Self.login(session, transport, email: "dono@exemplo.com")
        let owner = try #require(session.model).scope
        #expect(owner.defaults.integer(forKey: AppConstants.weeklyGoalDefaultsKey) == 25)
        #expect(try owner.keyStore(AppConstants.keychainAccount).read() == "chave-garmin")

        transport.reply(204)
        await session.account.signOut()
        await Self.login(session, transport, email: "outra@exemplo.com")
        let other = try #require(session.model).scope
        #expect(other.defaults.object(forKey: AppConstants.weeklyGoalDefaultsKey) == nil)
        #expect(try other.keyStore(AppConstants.keychainAccount).read() == nil)
    }
}
