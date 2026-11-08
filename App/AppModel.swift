import Foundation
import GarminAPI
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
    @ObservationIgnored private var engine: (key: String, engine: SyncEngine)?
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    init(
        container: ModelContainer,
        storeError: String? = nil,
        keyStore: any APIKeyStore,
        transport: any HTTPTransport = URLSessionTransport(),
        autoSyncEnabled: Bool = true
    ) {
        self.container = container
        self.storeError = storeError
        self.keyStore = keyStore
        self.transport = transport
        self.autoSyncEnabled = autoSyncEnabled
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
        engine = nil
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

    func syncNow() async {
        if let syncTask {
            await syncTask.value
            return
        }
        guard let key = currentKey() else {
            syncStatus = .failed(.missingKey)
            return
        }
        let engine = engine(for: key)
        syncStatus = .running(progress: 0)
        let task = Task { [weak self] in
            do {
                _ = try await engine.run { fraction in
                    Task { @MainActor in self?.updateProgress(fraction) }
                }
                self?.syncStatus = .finished(.now)
            } catch {
                self?.syncStatus = Task.isCancelled || error is CancellationError ? .idle : .failed(SyncFailure(error))
            }
        }
        syncTask = task
        await task.value
        syncTask = nil
    }

    func cancelSync() {
        syncTask?.cancel()
    }

    func deleteLocalData() async throws {
        if let syncTask {
            syncTask.cancel()
            await syncTask.value
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

    private func updateProgress(_ fraction: Double) {
        guard case .running(let current) = syncStatus, fraction > current else { return }
        syncStatus = .running(progress: fraction)
    }

    private func currentKey() -> String? {
        guard let key = (try? keyStore.read()) ?? nil, !key.isEmpty else { return nil }
        return key
    }

    private func engine(for key: String) -> SyncEngine {
        if let engine, engine.key == key { return engine.engine }
        let tokens = TokenProvider(apiKey: key, baseURL: GarminEndpoints.base, transport: transport)
        let client = GarminClient(tokens: tokens, transport: transport)
        let created = SyncEngine(source: client, container: container, today: { Day.today() })
        engine = (key, created)
        return created
    }
}
