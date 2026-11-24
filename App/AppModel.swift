import UIKit
import Foundation
import GarminAPI
import HealthImport
import Insights
import Metrics
import Narrative
import Observation
import RemoteSync
import Storage
import Sync
import SwiftData
import TrainingCore
import WorkoutAnalysis

@MainActor @Observable final class AppModel {
    let container: ModelContainer
    let scope: AccountScope
    let storeError: String?
    private(set) var syncStatus: SyncStatus = .idle
    private var returnsFromBackground = true
    private(set) var connectionStatus: ConnectionStatus = .untested
    private(set) var hasLocalData: Bool
    private(set) var newActivityIds: Set<Int64> = []
    private(set) var deferredFITRevision = 0
    private(set) var hasKey: Bool
    @ObservationIgnored let healthReader = HealthKitReader()
    @ObservationIgnored lazy var healthDataSource = HealthDataSource(reader: healthReader)
    var watchKind: WatchKind? {
        didSet { watchKind?.store(in: scope.defaults) }
    }
    let autoSyncEnabled: Bool
    let remoteSync: RemoteSyncModel
    let garminAccount: GarminAccountModel
    let mfitAccount: MFITAccountModel
    let account: AccountModel
    let strava: StravaModel
    let trainer: TrainerModel
    let garminZones: GarminZonesModel
    let exerciseFeedback: ExerciseFeedbackStore
    let exerciseNotes: ExerciseNotesStore
    let strengthPlanStore: StrengthPlanStore
    let snapshots: ScreenSnapshotStore
    let appUpdate = AppUpdateModel()
    let installExpiry = InstallExpiryModel()
    let installNotice = InstallNoticeModel()
    @ObservationIgnored let notifier: MorningNotifier
    @ObservationIgnored let connections = ConnectionNotifier()
    @ObservationIgnored let claudeInbox = ClaudeInboxNotifier()
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
    @ObservationIgnored private var deferredFITTask: Task<Void, Never>?
    @ObservationIgnored private var newMarkTask: Task<Void, Never>?
    @ObservationIgnored private var narrativeFailures: Set<String> = []
    @ObservationIgnored private var finishedSummary: (summary: TodaySummary, day: Day)?
    @ObservationIgnored private var latestWatchReadiness: WatchReadiness?

    init(
        container: ModelContainer,
        scope: AccountScope = .current,
        account: AccountModel? = nil,
        storeError: String? = nil,
        keyStore: any APIKeyStore,
        transport: any HTTPTransport = URLSessionTransport(),
        remoteKeyStore: any APIKeyStore = AccountScope.current.keyStore(AppConstants.remoteSyncKeychainAccount),
        watchTokenStore: any APIKeyStore = AccountScope.current.keyStore(AppConstants.watchTokenKeychainAccount),
        garminSessionStore: any APIKeyStore = AccountScope.current.keyStore(AppConstants.garminSessionKeychainAccount),
        mfitTokenStore: any APIKeyStore = AccountScope.current.keyStore(AppConstants.mfitTokenKeychainAccount),
        remoteDefaults: UserDefaults = AccountScope.current.defaults,
        trainerStore: TrainerStore = TrainerStore(),
        snapshots: ScreenSnapshotStore = ScreenSnapshotStore(),
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
        self.scope = scope
        self.hasLocalData = Self.storeHasData(container: container)
        self.scoreRefresher = ScoreRefresher {
            await PerformanceTrace.measure("notas") { await ScoreStore.refresh(container: container, ids: nil) }
            let updated = await PerformanceTrace.measure("clima dos treinos") { await ActivityWeatherStore.refresh(container: container) }
            if !updated.isEmpty { await PerformanceTrace.measure("notas com clima") { await ScoreStore.refresh(container: container, ids: nil) } }
        }
        self.storeError = storeError
        self.keyStore = keyStore
        self.transport = transport
        self.autoSyncEnabled = autoSyncEnabled
        self.makeNarrator = makeNarrator
        self.hasKey = ((try? keyStore.read()) ?? nil)?.isEmpty == false
        let storedWatch = WatchKind.stored(in: scope.defaults)
        let keyed = ((try? keyStore.read()) ?? nil)?.isEmpty == false
        let watch = storedWatch ?? (keyed ? WatchKind.garmin : nil)
        if storedWatch == nil { watch?.store(in: scope.defaults) }
        self.watchKind = watch
        let exerciseFeedback = ExerciseFeedbackStore(url: scope.exerciseFeedbackURL, stamps: SyncDocumentStamp(defaults: remoteDefaults, syncedKey: ExerciseFeedbackConstants.syncedStampKey, documentKey: ExerciseFeedbackConstants.documentStampKey))
        let exerciseNotes = ExerciseNotesStore(url: scope.exerciseNotesURL, stamps: SyncDocumentStamp(defaults: remoteDefaults, syncedKey: ExerciseNotesConstants.syncedStampKey, documentKey: ExerciseNotesConstants.documentStampKey))
        self.exerciseFeedback = exerciseFeedback
        self.exerciseNotes = exerciseNotes
        let strengthPlanStore = StrengthPlanStore(url: scope.strengthPlanURL, stamps: SyncDocumentStamp(defaults: remoteDefaults, syncedKey: StrengthPlanStoreConstants.syncedStampKey, documentKey: StrengthPlanStoreConstants.documentStampKey))
        self.strengthPlanStore = strengthPlanStore
        self.remoteSync = RemoteSyncModel(
            container: container,
            keyStore: remoteKeyStore,
            transport: transport,
            baseURL: remoteBaseURL,
            watchTokenStore: watchTokenStore,
            defaults: remoteDefaults,
            defaultsSuite: scope.suiteName,
            trainerStore: trainerStore,
            narrativeStore: GeneratedTextStore(defaults: remoteDefaults),
            blobStores: [
                PreferenceSyncStore(defaults: remoteDefaults),
                ChatSyncStore(folders: scope.chats.syncFolders, defaults: remoteDefaults),
                StrengthSyncStore(store: StrengthProgramStore(url: scope.strengthProgramURL), defaults: remoteDefaults),
                ExerciseFeedbackSyncStore(store: exerciseFeedback, defaults: remoteDefaults),
                ExerciseNotesSyncStore(store: exerciseNotes, defaults: remoteDefaults),
                StrengthPlanSyncStore(store: strengthPlanStore, defaults: remoteDefaults),
                TrainerSendSyncStore(defaults: remoteDefaults),
                ClaudeContextSyncStore(defaults: remoteDefaults),
                ClaudeInboxSyncStore(defaults: remoteDefaults),
                CredentialSyncStore(id: DeviceSyncConstants.watchTokenId, tokenStore: watchTokenStore, defaults: remoteDefaults),
                CredentialSyncStore(id: DeviceSyncConstants.mfitTokenId, tokenStore: mfitTokenStore, defaults: remoteDefaults),
                CredentialSyncStore(id: DeviceSyncConstants.garminKeyId, tokenStore: keyStore, defaults: remoteDefaults),
            ]
        )
        self.garminAccount = GarminAccountModel(
            store: KeychainGarminSessionStore(keychain: garminSessionStore),
            makeTransport: { URLSessionTransport(session: URLSession(configuration: .ephemeral)) }
        )
        self.mfitAccount = MFITAccountModel(
            store: mfitTokenStore,
            makeTransport: { URLSessionTransport(session: URLSession(configuration: .ephemeral)) }
        )
        self.account = account ?? AccountModel(transport: transport, baseURL: remoteBaseURL)
        self.strava = StravaModel(container: container, defaults: remoteDefaults)
        self.trainer = TrainerModel(container: container, store: trainerStore, defaults: remoteDefaults, strengthPlanStore: strengthPlanStore)
        self.garminZones = GarminZonesModel(defaults: remoteDefaults)
        self.snapshots = snapshots
        remoteSync.accountToken = { [weak self] in self?.account.token }
        remoteSync.readinessProvider = { [weak self] in self?.todayWatchReadiness() }
        remoteSync.trainerChanged = { [weak self] in
            self?.trainer.reloadFromStore()
            self?.trainer.scheduleAutoAdjust()
        }
        remoteSync.devicesChanged = { [weak self] kinds in
            guard let self else { return }
            if kinds.contains(.chat) { Task { await self.scope.chats.reload() } }
            if kinds.contains(.preference) {
                Task { await self.trainer.reloadRemoteStrengthPlan() }
                Task { await self.claudeInbox.check() }
                self.trainer.reloadKeptReadiness()
                self.mfitAccount.reloadFromStore()
                self.hasKey = self.currentKey() != nil
            }
        }
        trainer.onChange = { [weak self] in self?.remoteSync.scheduleSync() }
        NotificationCenter.default.addObserver(forName: WatchLinkConstants.needPlansNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                WorkoutSender.send(trainer: self.trainer, today: self.today())
            }
        }
        StrengthLiveModel.shared.garminClient = { [weak self] in self?.garminAccount.client }
        garminAccount.link = { [weak self] in
            guard let self, let token = self.account.token else { return nil }
            return GarminLinkClient(baseURL: remoteBaseURL, token: token, transport: transport)
        }
        strava.link = { [weak self] in
            guard let self, let token = self.account.token else { return nil }
            return StravaClient(baseURL: remoteBaseURL, token: token, transport: transport)
        }
        strava.imported = { [weak self] ids in await self?.didImportExternalRuns(ids) }
        StravaNotificationHandler.shared.handle = { [weak self] action, runId in await self?.strava.handleNotification(action: action, runId: runId) }
        strava.registerCategory()
        strava.connectionChanged = { [weak self] connected in
            guard let self else { return }
            if connected { await self.connections.restored(.strava) } else { await self.connections.lost(.strava) }
        }
    }

    var showsSkeleton: Bool { !hasLocalData && syncStatus.isRunning }
    var isRefreshing: Bool { hasLocalData && syncStatus.isRunning }

    var dataToken: SyncDataToken {
        var finished: Date?
        if case .finished(let date) = syncStatus { finished = date }
        return SyncDataToken(finished: finished, deferredFITRevision: deferredFITRevision)
    }

    nonisolated static func storeHasData(container: ModelContainer) -> Bool {
        let context = ModelContext(container)
        let activities = (try? context.fetchCount(FetchDescriptor<ActivityRecord>())) ?? 0
        let days = (try? context.fetchCount(FetchDescriptor<DailyRecord>())) ?? 0
        return activities + days > 0
    }

    static func live(
        scope: AccountScope, account: AccountModel, transport: any HTTPTransport, remoteBaseURL: URL, environment: [String: String]
    ) -> AppModel {
        let isTestHost = environment[AppConstants.testHostEnvironmentVariable] != nil
        let keyStore = scope.keyStore(AppConstants.keychainAccount)
        #if DEBUG
        if !isTestHost, let injected = environment[AppConstants.apiKeyEnvironmentVariable], !injected.isEmpty,
           ((try? keyStore.read()) ?? nil) == nil {
            try? keyStore.save(injected)
        }
        #endif
        let make = { (container: ModelContainer, storeError: String?, autoSync: Bool) in
            AppModel(
                container: container,
                scope: scope,
                account: account,
                storeError: storeError,
                keyStore: keyStore,
                transport: transport,
                remoteKeyStore: scope.keyStore(AppConstants.remoteSyncKeychainAccount),
                watchTokenStore: scope.keyStore(AppConstants.watchTokenKeychainAccount),
                garminSessionStore: scope.keyStore(AppConstants.garminSessionKeychainAccount),
                mfitTokenStore: scope.keyStore(AppConstants.mfitTokenKeychainAccount),
                remoteDefaults: scope.defaults,
                trainerStore: TrainerStore(url: scope.trainerURL, defaults: scope.defaults),
                snapshots: ScreenSnapshotStore(directory: scope.snapshotsFolder),
                remoteBaseURL: remoteBaseURL,
                autoSyncEnabled: autoSync,
                notifier: MorningNotifier(defaults: scope.defaults)
            )
        }
        if isTestHost { return make(inMemoryContainer(), nil, false) }
        do {
            return make(try TrainingSchema.container(url: scope.storeURL), nil, true)
        } catch {
            return make(inMemoryContainer(), String(describing: error), true)
        }
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

    func appBecameActive(syncs: Bool = true) async {
        await notifier.appOpened(now: .now)
        if syncs { await RaceNotices.refresh(container: container, client: garminAccount.client) }
        let defaults = UserDefaults.standard
        if notifier.settings.enabled, !defaults.bool(forKey: BackgroundConstants.permissionRequestedDefaultsKey) {
            defaults.set(true, forKey: BackgroundConstants.permissionRequestedDefaultsKey)
            Task { await UserNotificationScheduler.requestAuthorization() }
        }
        if notifier.settings.enabled, !defaults.bool(forKey: SleepArrivalConstants.permissionRequestedKey) {
            defaults.set(true, forKey: SleepArrivalConstants.permissionRequestedKey)
            Task {
                await SleepArrivalNotifier.shared.requestAccess()
                SleepArrivalNotifier.shared.start(model: self)
            }
        }
        let workouts = WorkoutFinishNotifier.shared
        if workouts.enabled, !defaults.bool(forKey: WorkoutNoticeConstants.permissionRequestedKey) {
            defaults.set(true, forKey: WorkoutNoticeConstants.permissionRequestedKey)
            Task {
                await UserNotificationScheduler.requestAuthorization()
                await workouts.requestAccess()
                workouts.start(model: self)
            }
        }
        if syncs { await syncNow(.launch) }
        await workouts.deliverReady(model: self)
    }

    func refreshInstallState() async {
        await installNotice.check()
        await appUpdate.refresh()
        await installExpiry.refresh()
    }

    func activate(force: Bool = false) {
        Task { await refreshInstallState() }
        WorkoutSender.send(trainer: trainer, today: today())
        StrengthLiveModel.shared.uploadPending()
        guard autoSyncEnabled, force || returnsFromBackground else { return }
        returnsFromBackground = false
        let syncs = force || AutoSyncPolicy.shouldSync(status: syncStatus, readinessComplete: todayReadinessComplete, now: .now)
        Task { await appBecameActive(syncs: syncs) }
    }

    func enteredBackground() {
        returnsFromBackground = true
        if runningTrigger?.runsInBackground != true { cancelSync() }
        BackgroundSync.schedule(readinessComplete: todayReadinessComplete)
        let task = UIApplication.shared.beginBackgroundTask()
        Task { [weak self] in
            await self?.remoteSync.syncNow()
            UIApplication.shared.endBackgroundTask(task)
        }
    }

    @discardableResult
    nonisolated static func runPostSyncWork(container: ModelContainer, today: Day) -> TodaySummary? {
        let context = ModelContext(container)
        try? autoLinkRaces(in: context, today: today)
        try? freezeEveTargets(in: context, today: today)
        PersonalRecords.refreshEfforts(in: context)
        return try? todaySummary(context: context, today: today)
    }

    func chooseWatch(_ kind: WatchKind) {
        guard watchKind != kind else { return }
        watchKind = kind
        Task {
            if kind == .appleWatch { try? await healthReader.requestAccess() }
            await syncNow(.settings)
        }
    }

    func quickMorningNotice() async {
        guard MorningQuickCheck.shouldRun(now: .now, calendar: .current, readinessComplete: todayReadinessComplete),
              watchKind != .appleWatch, syncTask == nil, let key = currentKey() else { return }
        let configuration = SyncEngineConfiguration(trigger: .background)
        let engine = configuration.makeEngine(source: client(for: key, configuration: configuration), container: container)
        guard let report = try? await engine.runMorning(), report.dailyUpserted > 0, !Task.isCancelled else { return }
        let container = container
        let day = Day.today()
        let summary = await Task.detached(priority: .userInitiated) {
            try? todaySummary(context: ModelContext(container), today: day)
        }.value
        guard let summary, !Task.isCancelled else { return }
        await handleMorningNotice(summary, trigger: .background)
    }

    @discardableResult
    func syncNow(_ trigger: SyncTrigger) async -> Bool {
        if trigger == .background { readinessComplete = false }
        if let syncTask {
            let running = runningTrigger
            await syncTask.value
            guard trigger.runsAfter(running), self.syncTask == nil else { return syncStatus.isFinished }
        }
        let usesHealth = watchKind == .appleWatch
        let key = currentKey()
        guard usesHealth || key != nil else {
            syncStatus = .failed(.missingKey)
            await remoteSync.syncNow()
            return false
        }
        if usesHealth { try? await healthReader.requestAccess() }
        let healthSource = usesHealth ? healthDataSource : nil
        runningTrigger = trigger
        syncStatus = .running(progress: 0)
        let pendingNarratives = narrativeTask
        pendingNarratives?.cancel()
        let pendingDeferredFIT = deferredFITTask
        pendingDeferredFIT?.cancel()
        let container = container
        let task = Task { [weak self] in
            await pendingNarratives?.value
            await pendingDeferredFIT?.value
            let hasOutdatedRuns = trigger == .pull ? await SyncEngineConfiguration.hasOutdatedRuns(container: container) : false
            let configuration = SyncEngineConfiguration(trigger: trigger, hasOutdatedRuns: hasOutdatedRuns)
            let garminSource: (any GarminDataSource)? = key.flatMap { self?.client(for: $0, configuration: configuration) }
            guard let source = healthSource ?? garminSource else { return }
            let engine = configuration.makeEngine(source: source, container: container)
            var processed: Set<Int64>?
            var deferringEngine: SyncEngine?
            do {
                let report: SyncReport
                if trigger == .workoutFinished {
                    report = try await PerformanceTrace.measure("sincronização leve") { try await engine.runLight() }
                } else {
                    report = try await PerformanceTrace.measure("sincronização") {
                        try await engine.run { fraction in
                            Task { @MainActor in self?.updateProgress(fraction) }
                        }
                    }
                }
                let day = Day.today()
                let summary = await PerformanceTrace.measure("pós-sincronização") {
                    await Task.detached(priority: .utility) {
                        Self.runPostSyncWork(container: container, today: day)
                    }.value
                }
                self?.syncStatus = .finished(.now)
                self?.trainer.scheduleAutoAdjust()
                self?.finishedSummary = summary.map { ($0, day) }
                processed = trigger.runsInBackground ? nil : report.processedActivityIds
                if trigger != .background { self?.markNew(report.processedActivityIds) }
                if configuration.deferredFITOlderThanDays != nil { deferringEngine = engine }
                if let summary, !Task.isCancelled { await self?.handleMorningNotice(summary, trigger: trigger) }
                if !trigger.runsInBackground { self?.refreshScores() }
            } catch {
                self?.syncStatus = Task.isCancelled || error is CancellationError ? .idle : .failed(SyncFailure(error))
            }
            self?.hasLocalData = Self.storeHasData(container: container)
            self?.syncTask = nil
            self?.runningTrigger = nil
            if let processed, !Task.isCancelled { self?.startNarratives(processed: processed) }
            if let deferringEngine, !Task.isCancelled { self?.startDeferredFIT(engine: deferringEngine) }
        }
        syncTask = task
        await task.value
        await reportGarminConnection(trigger: trigger)
        if syncStatus != .idle { await remoteSync.syncNow() }
        if let finished = finishedSummary {
            finishedSummary = nil
            await publishWatchReadiness(summary: finished.summary, day: finished.day)
        }
        WorkoutSender.send(trainer: trainer, today: today())
        StrengthLiveModel.shared.uploadPending()
        if syncStatus.isFinished { await garminZones.sync(container: container, client: garminAccount.client) }
        return syncStatus.isFinished
    }

    private func reportGarminConnection(trigger: SyncTrigger) async {
        switch syncStatus {
        case .failed(.invalidKey) where trigger.runsInBackground: await connections.lost(.garmin)
        case .finished: await connections.restored(.garmin)
        default: break
        }
    }

    nonisolated static func watchReadiness(summary: TodaySummary, day: Day, garmin: GarminReadinessScore? = nil) -> WatchReadiness {
        if summary.readinessMissingNight == true {
            return WatchReadiness(day: day.iso, score: nil, verdict: TodayConstants.watchMissingNight)
        }
        if !summary.readinessFromYesterday, let score = summary.readiness?.score, let phrase = summary.verdict.flatMap({ TodayConstants.verdictPhrases[$0] }) {
            return WatchReadiness(day: day.iso, score: score, verdict: phrase)
        }
        if let garmin, garmin.day == day.iso, let phrase = TodayConstants.verdictPhrases[readinessVerdict(score: garmin.score)] {
            return WatchReadiness(day: day.iso, score: garmin.score, verdict: phrase)
        }
        return WatchReadiness(day: day.iso, score: nil, verdict: nil)
    }

    func publishWatchReadiness(summary: TodaySummary?, day: Day) async {
        guard let summary else { return }
        let wantsGarmin = (summary.readiness == nil || summary.readinessFromYesterday) && summary.readinessMissingNight != true
        let garmin = wantsGarmin ? await GarminReadinessCache.refresh(client: garminAccount.client, day: day, defaults: scope.defaults) : nil
        var readiness = Self.watchReadiness(summary: summary, day: day, garmin: garmin)
        let planned = await plannedForWatch(week: day.weekStart)
        let container = container
        let weeklyGoal = scope.defaults.integer(forKey: AppConstants.weeklyGoalDefaultsKey)
        var weather: [HourlyWeather] = []
        if planned.contains(where: { $0.day == day.iso }), let coordinate = PlannedWeather.lastRunStart(context: container.mainContext) {
            weather = await PlannedWeather.forecast(day: day, coordinate: coordinate)
        }
        let forecast = weather
        let events = WatchCalendar.upcoming(now: .now)
        var status: String?
        if let client = garminAccount.client {
            status = WatchFaceBuilder.trainingStatusKey(try? await TrainingStatus.phrase(client: client, day: day))
        }
        let trainingStatus = status
        let nextWeek = WatchFaceBuilder.nextWeekText(plan: trainer.plan, today: day)
        readiness.face = await Task.detached(priority: .utility) {
            WatchFaceBuilder.face(
                context: ModelContext(container), summary: summary, today: day, planned: planned, weeklyGoalKm: weeklyGoal,
                weather: forecast, events: events, trainingStatus: trainingStatus, nextWeek: nextWeek
            )
        }.value
        guard readiness.score != nil || readiness.face != nil else { return }
        latestWatchReadiness = readiness
        await remoteSync.publishReadiness(readiness)
    }

    private func plannedForWatch(week start: Day) async -> [PlannedWorkout] {
        guard let client = garminAccount.client else { return [] }
        return (try? await PlannedWorkouts.fetch(client: client, from: start, through: start.adding(days: WatchFaceConstants.daysPerWeek - 1), ignoring: TrainerSendStore().settings().ignoredProviders)) ?? []
    }

    private func todayWatchReadiness() -> WatchReadiness? {
        guard let latestWatchReadiness, latestWatchReadiness.day == today().iso else { return nil }
        return latestWatchReadiness
    }

    func cancelSync() {
        syncTask?.cancel()
        narrativeTask?.cancel()
        deferredFITTask?.cancel()
    }

    func deleteLocalData() async throws {
        await stopWork()
        let context = container.mainContext
        for model in TrainingSchema.models {
            try deleteAll(model, in: context)
        }
        try context.save()
        snapshots.removeAll()
        hasLocalData = false
        newActivityIds = []
        syncStatus = .idle
    }

    func stopWork() async {
        if let syncTask {
            syncTask.cancel()
            await syncTask.value
        }
        if let narrativeTask {
            narrativeTask.cancel()
            await narrativeTask.value
        }
        if let deferredFITTask {
            deferredFITTask.cancel()
            await deferredFITTask.value
        }
        await scoreRefresher.finish()
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

    private func startDeferredFIT(engine: SyncEngine) {
        let task = Task(priority: .background) { [weak self] in
            defer { self?.deferredFITTask = nil }
            guard let report = try? await engine.runDeferredFIT(), !report.processedActivityIds.isEmpty, !Task.isCancelled else { return }
            self?.refreshScores()
            self?.deferredFITRevision += 1
            await self?.narrativeTask?.value
            if !Task.isCancelled { self?.startNarratives(processed: report.processedActivityIds) }
        }
        deferredFITTask = task
    }

    private func refreshScores() {
        let task = scoreRefresher.refresh()
        Task { [weak self] in
            await task.value
            await self?.strava.sendPending()
            await self?.strava.notifyNewRuns()
        }
    }

    func didImportExternalRuns(_ ids: Set<Int64>) async {
        let container = container
        let day = Day.today()
        _ = await Task.detached(priority: .utility) { Self.runPostSyncWork(container: container, today: day) }.value
        hasLocalData = Self.storeHasData(container: container)
        deferredFITRevision += 1
        markNew(ids)
        await scoreRefresher.refresh().value
        deferredFITRevision += 1
        startNarratives(processed: ids)
    }

    private func markNew(_ ids: Set<Int64>) {
        newMarkTask?.cancel()
        newActivityIds = ids
        guard !ids.isEmpty else { return }
        newMarkTask = Task { [weak self] in
            try? await Task.sleep(for: AppConstants.newBadgeDuration)
            guard !Task.isCancelled else { return }
            self?.newActivityIds = []
        }
    }

    private func morningStrengthLine() -> String? {
        let day = Day.today()
        let mfit = trainer.replacesMFIT(on: day) ? nil : StrengthSchedule().workouts(StrengthProgramStore().load().program, from: day, through: day).first?.title
        let generated = trainer.trainerSessions(on: day).first.flatMap { trainer.strengthWorkout(sessionId: $0.id, day: day) }
        return MorningStrengthText.line(mfitTitle: mfit, trainer: generated)
    }

    private func morningRunLine(_ summary: TodaySummary) async -> String? {
        guard watchKind != .appleWatch, garminAccount.client != nil else { return nil }
        return await MorningRunRace.run(timeout: TodayConstants.morningRunTimeout) { @MainActor [self] in
            await buildMorningRunLine(summary)
        }
    }

    private func buildMorningRunLine(_ summary: TodaySummary) async -> String? {
        guard let client = garminAccount.client else { return nil }
        let day = Day.today()
        guard let plans = try? await PlannedWorkouts.fetch(client: client, from: day, through: day, ignoring: TrainerSendStore().settings().ignoredProviders),
              !Task.isCancelled else { return nil }
        let recent = TodayModel.recentRuns(context: container.mainContext)
        guard let plan = DayAdjustText.pendingRun(plans, recent: recent, day: day) else { return nil }
        let forecast = await trainer.forecast(for: day)
        guard !Task.isCancelled else { return nil }
        let planned = trainer.plannedLegs(on: day.adding(days: -1))
        let heavyLegs = StrengthModel.legDay(in: container.mainContext, planned: planned, before: day) != nil
        let score = summary.readinessFromYesterday ? nil : summary.readiness?.score ?? nil
        let suggestion = trainer.readinessSuggestion(score: score, factor: TrainerModel.lowestFactor(summary.readiness))
        return DayAdjustText.morningLine(
            plan: plan, score: score, forecast: forecast, recent: recent, heavyLegs: heavyLegs, showsAdvice: suggestion == nil
        )
    }

    private func handleMorningNotice(_ summary: TodaySummary, trigger: SyncTrigger) async {
        readinessComplete = MorningNotifier.hasNightData(summary)
        readinessDay = today()
        guard trigger != .workoutFinished else { return }
        guard trigger == .background else {
            await notifier.foregroundSyncFinished(summary: summary, now: .now)
            return
        }
        await notifier.evaluate(summary: summary, now: .now, lastAppOpen: notifier.lastAppOpen, settings: notifier.settings, strengthLine: morningStrengthLine(), runLine: { await self.morningRunLine(summary) })
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
