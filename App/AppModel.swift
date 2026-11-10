import Foundation
import GarminAPI
import Insights
import Narrative
import Observation
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

    @ObservationIgnored private let keyStore: any APIKeyStore
    @ObservationIgnored private let transport: any HTTPTransport
    @ObservationIgnored private let makeNarrator: @MainActor () -> any Narrator
    @ObservationIgnored private var client: (key: String, client: GarminClient)?
    @ObservationIgnored private var syncTask: Task<Void, Never>?
    @ObservationIgnored private var runningTrigger: SyncTrigger?
    @ObservationIgnored private var narrativeTask: Task<Void, Never>?
    @ObservationIgnored private var narrativeFailures: Set<String> = []

    init(
        container: ModelContainer,
        storeError: String? = nil,
        keyStore: any APIKeyStore,
        transport: any HTTPTransport = URLSessionTransport(),
        autoSyncEnabled: Bool = true,
        makeNarrator: @escaping @MainActor () -> any Narrator = { Narrative.makeNarrator() }
    ) {
        self.container = container
        self.storeError = storeError
        self.keyStore = keyStore
        self.transport = transport
        self.autoSyncEnabled = autoSyncEnabled
        self.makeNarrator = makeNarrator
        self.hasKey = ((try? keyStore.read()) ?? nil)?.isEmpty == false
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
        if isTestHost {
            return AppModel(container: inMemoryContainer(), keyStore: keyStore, autoSyncEnabled: false)
        }
        do {
            return AppModel(container: try TrainingSchema.container(url: storeURL()), keyStore: keyStore)
        } catch {
            return AppModel(container: inMemoryContainer(), storeError: String(describing: error), keyStore: keyStore)
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
        client = nil
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

    func syncNow(_ trigger: SyncTrigger) async {
        if let syncTask {
            let running = runningTrigger
            await syncTask.value
            guard trigger == .settings, running != .settings, self.syncTask == nil else { return }
        }
        guard let key = currentKey() else {
            syncStatus = .failed(.missingKey)
            return
        }
        let engine = SyncEngineConfiguration(trigger: trigger).makeEngine(source: client(for: key), container: container)
        runningTrigger = trigger
        syncStatus = .running(progress: 0)
        let pendingNarratives = narrativeTask
        pendingNarratives?.cancel()
        let container = container
        let task = Task { [weak self] in
            await pendingNarratives?.value
            var processed: Set<Int64>?
            do {
                let report = try await engine.run { fraction in
                    Task { @MainActor in self?.updateProgress(fraction) }
                }
                await Task.detached(priority: .utility) {
                    try? freezeEveTargets(in: ModelContext(container), today: Day.today())
                }.value
                self?.syncStatus = .finished(.now)
                processed = report.processedActivityIds
            } catch {
                self?.syncStatus = Task.isCancelled || error is CancellationError ? .idle : .failed(SyncFailure(error))
            }
            self?.syncTask = nil
            self?.runningTrigger = nil
            if let processed, !Task.isCancelled { self?.startNarratives(processed: processed) }
        }
        syncTask = task
        await task.value
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
                context: container.mainContext,
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

    private func updateProgress(_ fraction: Double) {
        guard case .running(let current) = syncStatus, fraction > current else { return }
        syncStatus = .running(progress: fraction)
    }

    private func currentKey() -> String? {
        guard let key = (try? keyStore.read()) ?? nil, !key.isEmpty else { return nil }
        return key
    }

    private func client(for key: String) -> GarminClient {
        if let client, client.key == key { return client.client }
        let tokens = TokenProvider(apiKey: key, baseURL: GarminEndpoints.base, transport: transport)
        let created = GarminClient(tokens: tokens, transport: transport)
        client = (key, created)
        return created
    }
}
