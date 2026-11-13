import Foundation
import GarminAPI
import Insights
import Narrative
import Observation
import RemoteSync
import Storage
import Sync
import SwiftData
import TrainingCore

@MainActor @Observable final class AppModel {
    let container: ModelContainer
    let storeError: String?
    private(set) var syncStatus: SyncStatus = .idle
    private(set) var connectionStatus: ConnectionStatus = .untested
    private(set) var hasKey: Bool
    let autoSyncEnabled: Bool
    let remoteSync: RemoteSyncModel
    let garminAccount: GarminAccountModel
    @ObservationIgnored let notifier: MorningNotifier
    @ObservationIgnored private var readinessComplete: Bool
    @ObservationIgnored private var readinessDay: Day?
    @ObservationIgnored private let today: @Sendable () -> Day
    @ObservationIgnored var todayReadinessComplete: Bool { readinessComplete && readinessDay == today() }
    @ObservationIgnored let scoreRefresher: ScoreRefresher

    @ObservationIgnored private let keyStore: any APIKeyStore
    @ObservationIgnored private let transport: any HTTPTransport
    @ObservationIgnored private let makeNarrator: @MainActor () -> any Narrator
    @ObservationIgnored private var clients: [Bool: (key: String, client: GarminClient)] = [:]
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var runningTrigger: SyncTrigger?
    @ObservationIgnored private var narrativeTask: Task<Void, Never>?
    @ObservationIgnored private var narrativeFailures: Set<String> = []
    @ObservationIgnored private var finishedSummary: (summary: TodaySummary, day: Day)?
    @ObservationIgnored private var latestWatchReadiness: WatchReadiness?

    init(
        container: ModelContainer,
        storeError: String? = nil,
        keyStore: any APIKeyStore,
        transport: any HTTPTransport = URLSessionTransport(),
        remoteKeyStore: any APIKeyStore = KeychainKeyStore(account: AppConstants.remoteSyncKeychainAccount),
        watchTokenStore: any APIKeyStore = KeychainKeyStore(account: AppConstants.watchTokenKeychainAccount),
        garminSessionStore: any APIKeyStore = KeychainKeyStore(account: AppConstants.garminSessionKeychainAccount),
        remoteDefaults: UserDefaults = .standard,
        remoteBaseURL: URL = AppConstants.remoteSyncBaseURL,
        autoSyncEnabled: Bool = true,
        makeNarrator: @escaping @MainActor () -> any Narrator = { Narrative.makeNarrator() },
        notifier: MorningNotifier = MorningNotifier(),
        readinessComplete: Bool = false,
        readinessDay: Day? = nil,
        today: @escaping @Sendable () -> Day = { Day.today() }
    ) {
        self.readinessComplete = readinessComplete
        self.readinessDay = readinessDay
        self.today = today
        self.notifier = notifier
        self.container = container
        self.scoreRefresher = ScoreRefresher { await ScoreStore.refresh(container: container, ids: nil) }
        self.storeError = storeError
        self.keyStore = keyStore
        self.transport = transport
        self.autoSyncEnabled = autoSyncEnabled
        self.makeNarrator = makeNarrator
        self.hasKey = ((try? keyStore.read()) ?? nil)?.isEmpty == false
        self.remoteSync = RemoteSyncModel(
            container: container,
            keyStore: remoteKeyStore,
            transport: transport,
            baseURL: remoteBaseURL,
            watchTokenStore: watchTokenStore,
            defaults: remoteDefaults
        )
        self.garminAccount = GarminAccountModel(
            store: KeychainGarminSessionStore(keychain: garminSessionStore),
            makeTransport: { URLSessionTransport(session: URLSession(configuration: .ephemeral)) }
        )
        remoteSync.readinessProvider = { [weak self] in self?.todayWatchReadiness() }
    }

    static func live(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppModel {
        let isTestHost = environment[AppConstants.testHostEnvironmentVariable] != nil
        let keyStore = KeychainKeyStore()
        #if DEBUG
        if !isTestHost, let injected = environment[AppConstants.apiKeyEnvironmentVariable], !injected.isEmpty,
           ((try? keyStore.read()) ?? nil) == nil {
            try? keyStore.save(injected)
        }
        #endif
        let remoteBaseURL = RemoteSyncModel.baseURL(environment: environment)
        if isTestHost {
            return AppModel(container: inMemoryContainer(), keyStore: keyStore, remoteBaseURL: remoteBaseURL, autoSyncEnabled: false)
        }
        do {
            return AppModel(container: try TrainingSchema.container(url: storeURL()), keyStore: keyStore, remoteBaseURL: remoteBaseURL)
        } catch {
            return AppModel(container: inMemoryContainer(), storeError: String(describing: error), keyStore: keyStore, remoteBaseURL: remoteBaseURL)
        }
    }

    static func storeURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return support.appending(path: AppConstants.storeFileName)
    }

    private static func inMemoryContainer() -> ModelContainer {
        do {
            return try TrainingSchema.container(inMemory: true)
        } catch {
            fatalError("SwiftData em memória indisponível: \(error)")
        }
    }

    func saveKey(_ rawKey: String) throws {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        try keyStore.save(key)
        clients = [:]
        hasKey = true
        connectionStatus = .untested
    }

    func testConnection() async {
        guard let key = currentKey() else {
            connectionStatus = .failed(.missingKey)
            return
        }
        connectionStatus = .testing
        let tokens = TokenProvider(apiKey: key, baseURL: GarminEndpoints.base, transport: transport)
        do {
            _ = try await tokens.bearer()
            connectionStatus = .connected(.now)
        } catch {
            connectionStatus = .failed(SyncFailure(error))
        }
    }

    func appBecameActive() async {
        await notifier.appOpened(now: .now)
        let defaults = UserDefaults.standard
        if notifier.settings.enabled, !defaults.bool(forKey: BackgroundConstants.permissionRequestedDefaultsKey) {
            defaults.set(true, forKey: BackgroundConstants.permissionRequestedDefaultsKey)
            Task { await UserNotificationScheduler.requestAuthorization() }
        }
        await syncNow(.launch)
    }

    func enteredBackground() {
        if runningTrigger != .background { cancelSync() }
        BackgroundSync.schedule(readinessComplete: todayReadinessComplete)
    }

    @discardableResult
    nonisolated static func runPostSyncWork(container: ModelContainer, today: Day) -> TodaySummary? {
        let context = ModelContext(container)
        try? autoLinkRaces(in: context, today: today)
        try? freezeEveTargets(in: context, today: today)
        return try? todaySummary(context: context, today: today)
    }

    @discardableResult
    func syncNow(_ trigger: SyncTrigger) async -> Bool {
        if trigger == .background { readinessComplete = false }
        if let syncTask {
            let running = runningTrigger
            await syncTask.value
            guard trigger == .settings, running != .settings, self.syncTask == nil else { return syncStatus.isFinished }
        }
        guard let key = currentKey() else {
            syncStatus = .failed(.missingKey)
            await remoteSync.syncNow()
            return false
        }
        runningTrigger = trigger
        syncStatus = .running(progress: 0)
        let pendingNarratives = narrativeTask
        pendingNarratives?.cancel()
        let container = container
        let task = Task { [weak self] in
            await pendingNarratives?.value
            let hasOutdatedRuns = trigger == .pull ? await SyncEngineConfiguration.hasOutdatedRuns(container: container) : false
            let configuration = SyncEngineConfiguration(trigger: trigger, hasOutdatedRuns: hasOutdatedRuns)
            guard let source = self?.client(for: key, configuration: configuration) else { return }
            let engine = configuration.makeEngine(source: source, container: container)
            var processed: Set<Int64>?
            do {
                let report = try await engine.run { fraction in
                    Task { @MainActor in self?.updateProgress(fraction) }
                }
                let day = Day.today()
                let summary = await Task.detached(priority: .utility) {
                    Self.runPostSyncWork(container: container, today: day)
                }.value
                self?.syncStatus = .finished(.now)
                self?.finishedSummary = summary.map { ($0, day) }
                processed = trigger == .background ? nil : report.processedActivityIds
                if let summary, !Task.isCancelled { await self?.handleMorningNotice(summary, trigger: trigger) }
                if trigger != .background { self?.scoreRefresher.refresh() }
            } catch {
                self?.syncStatus = Task.isCancelled || error is CancellationError ? .idle : .failed(SyncFailure(error))
            }
            self?.syncTask = nil
            self?.runningTrigger = nil
            if let processed, !Task.isCancelled { self?.startNarratives(processed: processed) }
        }
        syncTask = task
        await task.value
        if syncStatus != .idle { await remoteSync.syncNow() }
        if let finished = finishedSummary {
            finishedSummary = nil
            await publishWatchReadiness(summary: finished.summary, day: finished.day)
        }
        return syncStatus.isFinished
    }

    nonisolated static func watchReadiness(summary: TodaySummary, day: Day) -> WatchReadiness? {
        guard let score = summary.readiness?.score, let phrase = summary.verdict.flatMap({ TodayConstants.verdictPhrases[$0] }) else { return nil }
        return WatchReadiness(day: day.iso, score: score, verdict: phrase)
    }

    func publishWatchReadiness(summary: TodaySummary?, day: Day) async {
        guard let readiness = summary.flatMap({ Self.watchReadiness(summary: $0, day: day) }) else { return }
        latestWatchReadiness = readiness
        await remoteSync.publishReadiness(readiness)
    }

    private func todayWatchReadiness() -> WatchReadiness? {
        guard let latestWatchReadiness, latestWatchReadiness.day == today().iso else { return nil }
        return latestWatchReadiness
    }

    func cancelSync() {
        syncTask?.cancel()
        narrativeTask?.cancel()
    }

    func deleteLocalData() async throws {
        if let syncTask {
            syncTask.cancel()
            await syncTask.value
        }
        if let narrativeTask {
            narrativeTask.cancel()
            await narrativeTask.value
        }
        await scoreRefresher.finish()
        let context = container.mainContext
        for model in TrainingSchema.models {
            try deleteAll(model, in: context)
        }
        try context.save()
        syncStatus = .idle
    }

    private func deleteAll<T: PersistentModel>(_ model: T.Type, in context: ModelContext) throws {
        try context.delete(model: model)
    }

    private func startNarratives(processed: Set<Int64>) {
        let narrator = makeNarrator()
        let skipping = narrativeFailures
        let task = Task { [weak self, container] in
            let failures = try? await NarrativeBackfill.run(
                container: container,
                narrator: narrator,
                processed: processed,
                limit: AppConstants.narrativeBackfillLimit,
                skipping: skipping
            )
            self?.narrativeFailures.formUnion(failures ?? [])
            self?.narrativeTask = nil
        }
        narrativeTask = task
    }

    private func handleMorningNotice(_ summary: TodaySummary, trigger: SyncTrigger) async {
        readinessComplete = MorningNotifier.hasNightData(summary)
        readinessDay = today()
        guard trigger == .background else {
            await notifier.foregroundSyncFinished(summary: summary, now: .now)
            return
        }
        await notifier.evaluate(summary: summary, now: .now, lastAppOpen: notifier.lastAppOpen, settings: notifier.settings)
    }

    private func updateProgress(_ fraction: Double) {
        guard case .running(let current) = syncStatus, fraction > current else { return }
        syncStatus = .running(progress: fraction)
    }

    private func currentKey() -> String? {
        guard let key = (try? keyStore.read()) ?? nil, !key.isEmpty else { return nil }
        return key
    }

    private func client(for key: String, configuration: SyncEngineConfiguration) -> GarminClient {
        let waits = configuration.waitsOnRateLimit
        if let cached = clients[waits], cached.key == key { return cached.client }
        let tokens = TokenProvider(apiKey: key, baseURL: GarminEndpoints.base, transport: transport)
        let created = configuration.makeClient(tokens: tokens, transport: transport)
        clients[waits] = (key, created)
        return created
    }
}
