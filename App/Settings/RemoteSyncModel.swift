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
    private(set) var isWorking = false
    private(set) var hasWatchToken: Bool
    private(set) var watchMessage: String?
    private(set) var watchError: String?
    private(set) var mcpTokenCreatedAt: Date?
    private(set) var mcpError: String?

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let keyStore: any APIKeyStore
    @ObservationIgnored private let transport: any HTTPTransport
    @ObservationIgnored private let baseURL: URL
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let authenticator: any DeviceOwnerAuthenticating
    @ObservationIgnored private let clipboard: any KeyClipboard
    @ObservationIgnored private let watchTokenStore: any APIKeyStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let defaultsSuite: String?
    @ObservationIgnored private let trainerStore: (any RemoteTrainerStore)?
    @ObservationIgnored private let narrativeStore: (any RemoteNarrativeStore)?
    @ObservationIgnored private let blobStores: [any RemoteBlobStore]
    @ObservationIgnored var accountToken: (@MainActor () -> String?)? {
        didSet { refreshStatus() }
    }
    @ObservationIgnored var devicesChanged: (@MainActor (Set<RemoteRecordKind>) -> Void)?
    @ObservationIgnored var readinessProvider: (@MainActor () -> WatchReadiness?)?
    @ObservationIgnored var trainerChanged: (@MainActor () -> Void)?
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
        watchTokenStore: any APIKeyStore = AccountScope.current.keyStore(AppConstants.watchTokenKeychainAccount),
        defaults: UserDefaults = AccountScope.current.defaults,
        defaultsSuite: String? = nil,
        trainerStore: (any RemoteTrainerStore)? = nil,
        narrativeStore: (any RemoteNarrativeStore)? = nil,
        blobStores: [any RemoteBlobStore] = []
    ) {
        self.blobStores = blobStores
        self.trainerStore = trainerStore
        self.narrativeStore = narrativeStore
        self.defaultsSuite = defaultsSuite
        self.clipboard = clipboard
        self.watchTokenStore = watchTokenStore
        self.defaults = defaults
        self.hasWatchToken = ((try? watchTokenStore.read()) ?? nil)?.isEmpty == false
        self.mcpTokenCreatedAt = defaults.object(forKey: ClaudeConstants.mcpTokenCreatedKey) as? Date
        self.container = container
        self.keyStore = keyStore
        self.transport = transport
        self.baseURL = baseURL
        self.debounce = debounce
        self.authenticator = authenticator
        self.status = .off
        self.lastSync = nil
        refreshStatus()
    }

    func refreshStatus() {
        guard status == .off, access() != nil else { return }
        status = .idle
        lastSync = currentState()?.remoteLastPush
    }

    static func baseURL(environment: [String: String]) -> URL {
        #if DEBUG
        if let text = environment[AppConstants.remoteSyncURLEnvironmentVariable], let url = URL(string: text), url.scheme != nil {
            return url
        }
        #endif
        return AppConstants.remoteSyncBaseURL
    }

    var isEnabled: Bool { status != .off }

    var chip: RemoteSyncChip? {
        switch status {
        case .waitingForNetwork(let pending): .waiting(C.waiting(pending))
        case .failed(let problem): .failed(C.problem(problem))
        case .off, .idle, .syncing: nil
        }
    }

    func scheduleSync() {
        guard access() != nil else { return }
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
        guard access() != nil else {
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

    func generateWatchToken() async {
        watchMessage = nil
        watchError = nil
        guard let access = access() else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let token: String
            do {
                token = try await registerWatchToken(access.client)
            } catch RemoteSyncError.tokenConflict {
                token = try await registerWatchToken(access.client)
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

    private func registerWatchToken(_ client: RemoteClient) async throws -> String {
        let token = WatchToken.generate()
        guard let hash = WatchToken.hash(token) else { throw RemoteSyncError.invalidSyncKey }
        try await client.putWatchToken(hash: hash)
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

    func generateMcpToken() async -> String? {
        mcpError = nil
        guard let access = access() else { return nil }
        isWorking = true
        defer { isWorking = false }
        do {
            let token = WatchToken.generate()
            guard let hash = WatchToken.hash(token) else { throw RemoteSyncError.invalidSyncKey }
            try await access.client.putMcpToken(hash: hash)
            let now = Date.now
            defaults.set(now, forKey: ClaudeConstants.mcpTokenCreatedKey)
            mcpTokenCreatedAt = now
            return token
        } catch {
            C.logger.error("Falha ao gerar token do MCP: \(String(describing: error), privacy: .public)")
            mcpError = ClaudeText.mcpGenerateFailed
            return nil
        }
    }

    func revokeMcpToken() async {
        mcpError = nil
        guard let access = access() else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await access.client.deleteMcpToken()
        } catch {
            C.logger.error("Falha ao revogar token do MCP: \(String(describing: error), privacy: .public)")
            mcpError = ClaudeText.mcpRevokeFailed
            return
        }
        defaults.removeObject(forKey: ClaudeConstants.mcpTokenCreatedKey)
        mcpTokenCreatedAt = nil
    }

    func revokeWatchToken() async {
        watchMessage = nil
        watchError = nil
        guard let access = access() else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await access.client.deleteWatchToken()
        } catch {
            C.logger.error("Falha ao revogar token do relógio: \(String(describing: error), privacy: .public)")
            watchError = C.watchRevokeFailed
            return
        }
        forgetWatchToken()
        CredentialSyncStore.recordSignOut(id: DeviceSyncConstants.watchTokenId, defaults: defaults)
        watchMessage = C.watchRevoked
    }

    func publishReadiness(_ readiness: WatchReadiness) async {
        guard let access = access(), currentWatchToken() != nil else { return }
        guard lastPublishedReadiness() != readiness else { return }
        do {
            try await access.client.putReadiness(readiness)
        } catch {
            C.logger.error("Falha ao enviar prontidão ao relógio: \(String(describing: error), privacy: .public)")
            return
        }
        guard self.access()?.identity == access.identity, currentWatchToken() != nil else { return }
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
        guard let access = access() else {
            status = .off
            return
        }
        status = .syncing
        do {
            let report = try await RemoteSyncEngine(container: container, client: access.client, keys: access.keys, defaultsSuite: defaultsSuite, trainerStore: trainerStore, narrativeStore: narrativeStore, blobStores: blobStores).sync()
            guard self.access()?.identity == access.identity else { return }
            finished(report)
        } catch let error as URLError where Self.isNetwork(error) {
            guard self.access()?.identity == access.identity else { return }
            status = .waitingForNetwork(pending: pendingCount())
        } catch {
            C.logger.error("Falha no sync remoto: \(String(describing: error), privacy: .public)")
            guard self.access()?.identity == access.identity else { return }
            status = .failed(Self.problem(for: error))
        }
    }

    private func finished(_ report: RemoteSyncReport) {
        tooLarge = report.tooLarge.count
        lastSync = currentState()?.remoteLastPush ?? .now
        status = report.quotaExceeded ? .failed(.quotaExceeded) : .idle
        if report.trainerChanged { trainerChanged?() }
        if !report.changedKinds.isEmpty { devicesChanged?(report.changedKinds) }
        if report.changedKinds.contains(.preference) { hasWatchToken = currentWatchToken() != nil }
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

    func legacyBearer() -> String? {
        currentKey().flatMap { try? RemoteKeys(syncKey: $0).bearer }
    }

    private func access() -> RemoteSyncAccess? {
        let keys = currentKey().flatMap { try? RemoteKeys(syncKey: $0) }
        if let token = accountToken?(), !token.isEmpty {
            return RemoteSyncAccess(client: RemoteClient(baseURL: baseURL, bearer: token, transport: transport), keys: keys, identity: token)
        }
        guard let keys else { return nil }
        return RemoteSyncAccess(client: RemoteClient(baseURL: baseURL, keys: keys, transport: transport), keys: keys, identity: keys.bearer)
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
