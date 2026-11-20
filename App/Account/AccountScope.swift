import CryptoKit
import Foundation
import Synchronization

final class AccountScope: Sendable {
    private typealias C = AccountScopeConstants

    let id: String
    let suiteName: String
    nonisolated(unsafe) let defaults: UserDefaults
    let supportFolder: URL
    let cachesFolder: URL
    let chats: AccountChatStores
    private let keychain: @Sendable (String) -> any APIKeyStore

    init(id: String, suiteName: String, supportFolder: URL, cachesFolder: URL, keychain: @escaping @Sendable (String) -> any APIKeyStore) {
        self.id = id
        self.suiteName = suiteName
        self.defaults = UserDefaults(suiteName: suiteName) ?? UserDefaults()
        self.supportFolder = supportFolder
        self.cachesFolder = cachesFolder
        self.chats = AccountChatStores(folder: supportFolder)
        self.keychain = keychain
    }

    convenience init(id: String, supportRoot: URL, cachesRoot: URL, keychain: @escaping @Sendable (String) -> any APIKeyStore) {
        self.init(
            id: id,
            suiteName: C.suitePrefix + id,
            supportFolder: supportRoot.appending(path: C.accountsFolderName).appending(path: id, directoryHint: .isDirectory),
            cachesFolder: cachesRoot.appending(path: C.accountsFolderName).appending(path: id, directoryHint: .isDirectory),
            keychain: keychain
        )
    }

    var storeURL: URL { supportFolder.appending(path: AppConstants.storeFileName) }

    var trainerURL: URL { supportFolder.appending(path: TrainerConstants.storeFileName) }
    var strengthProgramURL: URL { supportFolder.appending(path: StrengthConstants.programFileName) }
    var exerciseFeedbackURL: URL { supportFolder.appending(path: ExerciseFeedbackConstants.fileName) }
    var exerciseNotesURL: URL { supportFolder.appending(path: ExerciseNotesConstants.fileName) }
    var strengthPlanURL: URL { supportFolder.appending(path: StrengthPlanStoreConstants.fileName) }
    var paceProURL: URL { supportFolder.appending(path: RacePlanConstants.cacheFileName) }

    var snapshotsFolder: URL { cachesFolder.appending(path: ScreenSnapshotConstants.directoryName, directoryHint: .isDirectory) }

    func keyStore(_ account: String) -> any APIKeyStore {
        keychain(account + C.keychainSeparator + id)
    }

    func prepare() {
        try? FileManager.default.createDirectory(at: supportFolder, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: cachesFolder, withIntermediateDirectories: true)
    }

    func erase() {
        try? FileManager.default.removeItem(at: supportFolder)
        try? FileManager.default.removeItem(at: cachesFolder)
        C.keychainAccounts.forEach { try? keyStore($0).delete() }
        defaults.removePersistentDomain(forName: suiteName)
    }

    static func id(email: String) -> String {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return SHA256.hash(data: Data(normalized.utf8)).prefix(C.idByteCount).map { String(format: "%02x", $0) }.joined()
    }

    static func live(email: String) -> AccountScope {
        live(id: id(email: email))
    }

    static let testHost = AccountScope(
        id: C.testHostId,
        supportRoot: FileManager.default.temporaryDirectory,
        cachesRoot: FileManager.default.temporaryDirectory,
        keychain: { KeychainKeyStore(account: $0) }
    )

    private static let signedOut = AccountScope(
        id: C.signedOutId,
        supportRoot: FileManager.default.temporaryDirectory,
        cachesRoot: FileManager.default.temporaryDirectory,
        keychain: { KeychainKeyStore(account: $0) }
    )

    private static let opened = Mutex<AccountScope?>(nil)

    static var current: AccountScope {
        opened.withLock { $0 } ?? signedOut
    }

    static func publish(_ scope: AccountScope?) {
        opened.withLock { $0 = scope }
    }

    private static func live(id: String) -> AccountScope {
        AccountScope(id: id, supportRoot: .applicationSupportDirectory, cachesRoot: .cachesDirectory, keychain: { KeychainKeyStore(account: $0) })
    }
}
