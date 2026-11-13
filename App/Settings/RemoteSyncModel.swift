import Foundation
import GarminAPI
import Observation
import RemoteSync
import Storage
import SwiftData

@MainActor @Observable final class RemoteSyncModel {
    typealias C = RemoteSyncSettingsConstants

    private(set) var status: RemoteSyncStatus
    private(set) var lastSync: Date?
    private(set) var tooLarge = 0
    private(set) var actionMessage: String?
    private(set) var pasteError: String?
    private(set) var isWorking = false
    private(set) var keyMessage: String?
    private(set) var hasWatchToken: Bool
    private(set) var watchMessage: String?
    private(set) var watchError: String?

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let keyStore: any APIKeyStore
    @ObservationIgnored private let transport: any HTTPTransport
    @ObservationIgnored private let baseURL: URL
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let authenticator: any DeviceOwnerAuthenticating
    @ObservationIgnored private let clipboard: any KeyClipboard
    @ObservationIgnored private let watchTokenStore: any APIKeyStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var readinessProvider: (@MainActor () -> WatchReadiness?)?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var runningTask: Task<Void, Never>?
    @ObservationIgnored private var rerunRequested = false

    init(
        container: ModelContainer,
        keyStore: any APIKeyStore,
        transport: any HTTPTransport,
        baseURL: URL,
        debounce: Duration = AppConstants.remoteSyncDebounce,
        authenticator: any DeviceOwnerAuthenticating = DeviceOwnerAuthenticator(),
        clipboard: any KeyClipboard = SystemKeyClipboard(),
        watchTokenStore: any APIKeyStore = KeychainKeyStore(account: AppConstants.watchTokenKeychainAccount),
        defaults: UserDefaults = .standard
    ) {
        self.clipboard = clipboard
        self.watchTokenStore = watchTokenStore
        self.defaults = defaults
        self.hasWatchToken = ((try? watchTokenStore.read()) ?? nil)?.isEmpty == false
        self.container = container
        self.keyStore = keyStore
        self.transport = transport
        self.baseURL = baseURL
        self.debounce = debounce
        self.authenticator = authenticator
        let hasKey = ((try? keyStore.read()) ?? nil)?.isEmpty == false
        self.status = hasKey ? .idle : .off
        self.lastSync = nil
        if hasKey { lastSync = currentState()?.remoteLastPush }
    }

    static func baseURL(environment: [String: String]) -> URL {
        #if DEBUG
        if let text = environment[AppConstants.remoteSyncURLEnvironmentVariable], let url = URL(string: text), url.scheme != nil {
            return url
        }
        #endif
        return AppConstants.remoteSyncBaseURL
    }

    static func check(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return C.keyEmpty }
        guard trimmed.count == C.keyLength else { return C.keyLength(trimmed.count) }
        guard trimmed.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { return C.keyCharacters }
        guard (try? RemoteKeys(syncKey: trimmed)) != nil else { return C.keyMalformed }
        return nil
    }

    var isEnabled: Bool { status != .off }

    var chip: RemoteSyncChip? {
        switch status {
        case .waitingForNetwork(let pending): .waiting(C.waiting(pending))
        case .failed(let problem): .failed(C.problem(problem))
        case .off, .idle, .syncing: nil
        }
    }

    func localCounts() -> RemoteSyncCounts {
        let context = container.mainContext
        let races = (try? context.fetchCount(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.deletedAt == nil }))) ?? 0
        let decisions = (try? context.fetchCount(FetchDescriptor<RaceDecisionRecord>(predicate: #Predicate { $0.deletedAt == nil }))) ?? 0
        return RemoteSyncCounts(races: races, decisions: decisions)
    }

    func activate() async {
        actionMessage = nil
        isWorking = true
        defer { isWorking = false }
        let key = RemoteKeys.generateSyncKey()
        do {
            let keys = try RemoteKeys(syncKey: key)
            try await client(keys).createAccount()
            try keyStore.save(key)
        } catch {
            C.logger.error("Falha ao ativar sync remoto: \(String(describing: error), privacy: .public)")
            actionMessage = error as? RemoteSyncError == .rateLimited ? C.accountLimit : C.activateFailed
            return
        }
        status = .idle
        await syncNow()
    }

    func connect(_ text: String) async -> Bool {
        if let problem = Self.check(text) {
            pasteError = problem
            return false
        }
        pasteError = nil
        isWorking = true
        defer { isWorking = false }
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let keys = try RemoteKeys(syncKey: key)
            let report = try await RemoteSyncEngine(container: container, client: client(keys), keys: keys).sync()
            try keyStore.save(key)
            finished(report)
            return true
        } catch RemoteSyncError.unauthorized {
            pasteError = C.keyNotFoundOnServer
        } catch let error as URLError where Self.isNetwork(error) {
            pasteError = C.noConnection
        } catch {
            pasteError = C.problem(Self.problem(for: error))
        }
        return false
    }

    func clearPasteError() {
        pasteError = nil
    }

    func scheduleSync() {
        guard currentKey() != nil else { return }
        debounceTask?.cancel()
        let debounce = debounce
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func waitForScheduledSync() async {
        await debounceTask?.value
    }

    func syncNow() async {
        guard currentKey() != nil else {
            status = .off
            return
        }
        if let runningTask {
            rerunRequested = true
            await runningTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            repeat {
                rerunRequested = false
                await runOnce()
            } while rerunRequested
            runningTask = nil
        }
        runningTask = task
        await task.value
    }

    func disable() async {
        await disable(revokingWatchToken: true)
    }

    private func disable(revokingWatchToken: Bool) async {
        debounceTask?.cancel()
        rerunRequested = false
        if revokingWatchToken, currentWatchToken() != nil, let key = currentKey(), let keys = try? RemoteKeys(syncKey: key) {
            do {
                try await client(keys).deleteWatchToken()
            } catch {
                C.logger.error("Falha ao revogar token do relógio ao desligar: \(String(describing: error), privacy: .public)")
            }
        }
        try? keyStore.delete()
        forgetWatchToken()
        await runningTask?.value
        let context = container.mainContext
        for state in (try? context.fetch(FetchDescriptor<SyncState>())) ?? [] {
            state.remoteCursor = 0
            state.remoteLastPush = nil
        }
        try? context.save()
        status = .off
        lastSync = nil
        tooLarge = 0
        actionMessage = nil
    }

    func deleteServerData() async -> Bool {
        guard let key = currentKey(), let keys = try? RemoteKeys(syncKey: key) else { return false }
        actionMessage = nil
        isWorking = true
        defer { isWorking = false }
        debounceTask?.cancel()
        rerunRequested = false
        await runningTask?.value
        do {
            try await client(keys).deleteAccount()
        } catch {
            C.logger.error("Falha ao apagar conta remota: \(String(describing: error), privacy: .public)")
            actionMessage = C.deleteServerFailed
            return false
        }
        await disable(revokingWatchToken: false)
        return true
    }

    func revealKey(reason: String) async -> String? {
        keyMessage = nil
        guard let key = currentKey() else { return nil }
        guard let granted = await deviceOwnerAllows(reason: reason) else {
            keyMessage = C.noPasscode
            return nil
        }
        return granted ? key : nil
    }

    @discardableResult
    func copyKey() async -> Bool {
        guard let key = await revealKey(reason: C.copyReason) else { return false }
        clipboard.copy(key)
        keyMessage = C.keyCopied
        return true
    }

    func generateWatchToken() async {
        watchMessage = nil
        watchError = nil
        guard let key = currentKey(), let keys = try? RemoteKeys(syncKey: key) else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let token: String
            do {
                token = try await registerWatchToken(keys)
            } catch RemoteSyncError.tokenConflict {
                token = try await registerWatchToken(keys)
            }
            try watchTokenStore.save(token)
        } catch {
            C.logger.error("Falha ao gerar token do relógio: \(String(describing: error), privacy: .public)")
            watchError = C.watchGenerateFailed
            return
        }
        defaults.removeObject(forKey: AppConstants.watchReadinessDefaultsKey)
        hasWatchToken = true
        watchMessage = C.watchInstructions
        if let readiness = readinessProvider?() { await publishReadiness(readiness) }
    }

    private func registerWatchToken(_ keys: RemoteKeys) async throws -> String {
        let token = WatchToken.generate()
        guard let hash = WatchToken.hash(token) else { throw RemoteSyncError.invalidSyncKey }
        try await client(keys).putWatchToken(hash: hash)
        return token
    }

    func revealWatchToken() async -> String? {
        watchMessage = nil
        guard let token = currentWatchToken() else { return nil }
        guard let granted = await deviceOwnerAllows(reason: C.watchRevealReason) else {
            watchMessage = C.watchNoPasscode
            return nil
        }
        return granted ? token : nil
    }

    @discardableResult
    func copyWatchToken() async -> Bool {
        watchMessage = nil
        guard let token = currentWatchToken() else { return false }
        guard let granted = await deviceOwnerAllows(reason: C.watchCopyReason) else {
            watchMessage = C.watchNoPasscode
            return false
        }
        guard granted else { return false }
        clipboard.copy(token)
        watchMessage = C.watchTokenCopied
        return true
    }

    func revokeWatchToken() async {
        watchMessage = nil
        watchError = nil
        guard let key = currentKey(), let keys = try? RemoteKeys(syncKey: key) else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await client(keys).deleteWatchToken()
        } catch {
            C.logger.error("Falha ao revogar token do relógio: \(String(describing: error), privacy: .public)")
            watchError = C.watchRevokeFailed
            return
        }
        forgetWatchToken()
        watchMessage = C.watchRevoked
    }

    func publishReadiness(_ readiness: WatchReadiness) async {
        guard let key = currentKey(), let keys = try? RemoteKeys(syncKey: key), currentWatchToken() != nil else { return }
        guard lastPublishedReadiness() != readiness else { return }
        do {
            try await client(keys).putReadiness(readiness)
        } catch {
            C.logger.error("Falha ao enviar prontidão ao relógio: \(String(describing: error), privacy: .public)")
            return
        }
        guard currentKey() == key, currentWatchToken() != nil else { return }
        defaults.set(try? JSONEncoder().encode(readiness), forKey: AppConstants.watchReadinessDefaultsKey)
    }

    private func lastPublishedReadiness() -> WatchReadiness? {
        defaults.data(forKey: AppConstants.watchReadinessDefaultsKey).flatMap { try? JSONDecoder().decode(WatchReadiness.self, from: $0) }
    }

    private func forgetWatchToken() {
        try? watchTokenStore.delete()
        defaults.removeObject(forKey: AppConstants.watchReadinessDefaultsKey)
        hasWatchToken = false
    }

    private func currentWatchToken() -> String? {
        guard let token = (try? watchTokenStore.read()) ?? nil, !token.isEmpty else { return nil }
        return token
    }

    private func deviceOwnerAllows(reason: String) async -> Bool? {
        switch await authenticator.authenticate(reason: reason) {
        case .granted: true
        case .denied: false
        case .unavailable: nil
        }
    }

    private func runOnce() async {
        guard let key = currentKey(), let keys = try? RemoteKeys(syncKey: key) else {
            status = .off
            return
        }
        status = .syncing
        do {
            let report = try await RemoteSyncEngine(container: container, client: client(keys), keys: keys).sync()
            guard currentKey() == key else { return }
            finished(report)
        } catch let error as URLError where Self.isNetwork(error) {
            guard currentKey() == key else { return }
            status = .waitingForNetwork(pending: pendingCount())
        } catch {
            C.logger.error("Falha no sync remoto: \(String(describing: error), privacy: .public)")
            guard currentKey() == key else { return }
            status = .failed(Self.problem(for: error))
        }
    }

    private func finished(_ report: RemoteSyncReport) {
        tooLarge = report.tooLarge.count
        lastSync = currentState()?.remoteLastPush ?? .now
        status = report.quotaExceeded ? .failed(.quotaExceeded) : .idle
    }

    private func pendingCount() -> Int {
        let context = container.mainContext
        let after = currentState()?.remoteLastPush ?? .distantPast
        let races = (try? context.fetchCount(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.updatedAt > after }))) ?? 0
        let decisions = (try? context.fetchCount(FetchDescriptor<RaceDecisionRecord>(predicate: #Predicate { $0.updatedAt > after }))) ?? 0
        return races + decisions
    }

    private func currentState() -> SyncState? {
        ((try? container.mainContext.fetch(FetchDescriptor<SyncState>())) ?? [])
            .max { ($0.remoteLastPush ?? .distantPast) < ($1.remoteLastPush ?? .distantPast) }
    }

    private func currentKey() -> String? {
        guard let key = (try? keyStore.read()) ?? nil, !key.isEmpty else { return nil }
        return key
    }

    private func client(_ keys: RemoteKeys) -> RemoteClient {
        RemoteClient(baseURL: baseURL, keys: keys, transport: transport)
    }

    private static func isNetwork(_ error: URLError) -> Bool {
        [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff]
            .contains(error.code)
    }

    private static func problem(for error: any Error) -> RemoteSyncProblem {
        switch error as? RemoteSyncError {
        case .unauthorized: .keyNotFound
        case .rateLimited: .busy
        case .quotaExceeded: .quotaExceeded
        case .tamperedPayload: .unreadable
        default: .other
        }
    }
}
