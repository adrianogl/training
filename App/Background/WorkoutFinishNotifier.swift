import Foundation
import HealthKit
import SwiftData
import UIKit

@MainActor final class WorkoutFinishNotifier {
    static let shared = WorkoutFinishNotifier()

    private typealias C = WorkoutNoticeConstants

    private let store = HKHealthStore()
    private let fixedDefaults: UserDefaults?
    private let scheduler = UserNotificationScheduler()
    private var observing = false
    private var processing = false
    private var rerun = false
    private var rerunByWorkout = false
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    private weak var model: AppModel?

    init(defaults: UserDefaults? = nil) {
        self.fixedDefaults = defaults
    }

    private var defaults: UserDefaults { fixedDefaults ?? AccountScope.current.defaults }

    var enabled: Bool { defaults.object(forKey: C.enabledKey) as? Bool ?? C.defaultEnabled }

    private var enabledAt: Date? { defaults.object(forKey: C.enabledAtKey) as? Date }

    private var supported: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    func requestAccess() async {
        guard supported, HKHealthStore.isHealthDataAvailable() else { return }
        try? await store.requestAuthorization(toShare: [], read: Set(observedTypes))
    }

    func start(model: AppModel) {
        guard enabled, supported, HKHealthStore.isHealthDataAvailable() else { return }
        self.model = model
        if enabledAt == nil {
            defaults.set(Date.now, forKey: C.enabledAtKey)
            C.logger.info("aviso ligado, enabledAt gravado")
        }
        if !observing {
            observing = true
            observedTypes.forEach(observe)
        }
        for type in observedTypes {
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, error in
                if let error { C.logger.error("background delivery de \(type.identifier, privacy: .public) falhou: \(error.localizedDescription, privacy: .public)") }
            }
        }
    }

    private var observedTypes: [HKSampleType] {
        [HKObjectType.workoutType()] + C.wakeTypes.map { HKQuantityType($0) }
    }

    private func observe(_ type: HKSampleType) {
        let byWorkout = type == HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
            nonisolated(unsafe) let completion = completion
            if let error {
                C.logger.error("observer com erro: \(error.localizedDescription, privacy: .public)")
                completion()
                return
            }
            Task { @MainActor in
                C.logger.info("dado novo no Health: \(type.identifier, privacy: .public)")
                if let self, let model = self.model {
                    let newRun = byWorkout ? await self.noteHealthRun() : false
                    await self.refresh(model: model, byWorkout: newRun)
                }
                completion()
            }
        }
        store.execute(query)
    }

    private func noteHealthRun() async -> Bool {
        guard let enabledAt else { return false }
        let matched = defaults.object(forKey: C.matchedStartKey) as? Date
        guard let expected = WorkoutNoticeSelection.newExpectation(healthRun: await latestHealthRun(), enabledAt: enabledAt, matchedStart: matched, current: expectedRun, now: .now, window: C.expectedRunWindow) else { return false }
        saveExpectedRun(expected)
        C.logger.info("corrida nova no Health, esperando o Garmin")
        return true
    }

    private func latestHealthRun() async -> DateInterval? {
        let window = HKQuery.predicateForSamples(withStart: Date.now.addingTimeInterval(-C.recentWindow), end: nil)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [window, HKQuery.predicateForWorkouts(with: .running)])
        let latest = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 1, sortDescriptors: latest) { _, samples, _ in
                continuation.resume(returning: samples?.first.map { DateInterval(start: $0.startDate, end: $0.endDate) })
            }
            store.execute(query)
        }
    }

    private func disableDelivery() {
        observedTypes.forEach { store.disableBackgroundDelivery(for: $0) { _, _ in } }
    }

    func detach() {
        model = nil
        disableDelivery()
    }

    func stop() {
        defaults.removeObject(forKey: C.enabledAtKey)
        disableDelivery()
    }

    func refresh(model: AppModel, byWorkout: Bool = false) async {
        guard enabled, supported, let enabledAt else { return }
        guard UIApplication.shared.applicationState != .active else {
            await deliverReady(model: model)
            return
        }
        guard !processing else {
            rerun = true
            rerunByWorkout = rerunByWorkout || byWorkout
            return
        }
        processing = true
        defer { processing = false }
        var forced = byWorkout
        repeat {
            rerun = false
            await process(model: model, enabledAt: enabledAt, byWorkout: forced)
            forced = rerunByWorkout
            rerunByWorkout = false
        } while rerun
    }

    func deliverReady(model: AppModel) async {
        guard enabled, supported, let enabledAt, !processing else { return }
        var queue = PendingWorkoutQueue.load(defaults: defaults)
        queue.prune(now: .now, lifetime: C.recentWindow)
        await deliverFromStore(model: model, enabledAt: enabledAt, queue: &queue)
    }

    private func process(model: AppModel, enabledAt: Date, byWorkout: Bool) async {
        let now = Date.now
        var queue = PendingWorkoutQueue.load(defaults: defaults)
        queue.prune(now: now, lifetime: C.recentWindow)
        queue.save(defaults: defaults)
        let lastCheck = defaults.object(forKey: C.lastCheckKey) as? Date
        let check = WorkoutNoticeSelection.nextCheck(forced: byWorkout, pending: hasWork(queue, now: now), lastCheck: lastCheck, now: now, interval: C.garminCheckInterval)
        if case .after(let next) = check {
            C.logger.info("checagem no Garmin feita há pouco, próxima agendada")
            BackgroundSync.scheduleWorkoutRetry(at: next)
            return
        }

        beginBackgroundTask(model: model)
        defer { endBackgroundTask() }
        await syncAndDeliver(model: model, enabledAt: enabledAt, queue: &queue)
        var attempt = 0
        while hasWork(queue, now: .now), WorkoutQuickRetry.shouldRetry(attempt: attempt, remaining: UIApplication.shared.backgroundTimeRemaining) {
            attempt += 1
            try? await Task.sleep(for: C.quickRetryDelay)
            guard !Task.isCancelled else { break }
            C.logger.info("nota ainda não saiu, tentativa rápida \(attempt)")
            await syncAndDeliver(model: model, enabledAt: enabledAt, queue: &queue)
        }
        await model.strava.sendPending()
        guard hasWork(queue, now: .now) else { return }
        BackgroundSync.scheduleWorkoutRetry()
        let pending = queue.items.count
        C.logger.info("aviso adiado, pendentes: \(pending)")
    }

    private func hasWork(_ queue: PendingWorkoutQueue, now: Date) -> Bool {
        !queue.items.isEmpty || WorkoutNoticeSelection.expecting(expectedRun, now: now)
    }

    private func syncAndDeliver(model: AppModel, enabledAt: Date, queue: inout PendingWorkoutQueue) async {
        C.logger.info("sync leve começou")
        let synced = await model.syncNow(.workoutFinished)
        C.logger.info("sync leve terminou, ok: \(synced)")
        if synced { defaults.set(Date.now, forKey: C.lastCheckKey) }
        await deliverFromStore(model: model, enabledAt: enabledAt, queue: &queue)
    }

    private func deliverFromStore(model: AppModel, enabledAt: Date, queue: inout PendingWorkoutQueue) async {
        let now = Date.now
        let container = model.container
        let runs = await Task.detached(priority: .utility) {
            WorkoutNoticeSelection.finishedRuns(since: now.addingTimeInterval(-C.fetchWindow), in: ModelContext(container))
        }.value
        if let expected = expectedRun, WorkoutNoticeSelection.matches(expected, runs: runs, tolerance: C.matchTolerance) {
            defaults.set(expected.start, forKey: C.matchedStartKey)
            saveExpectedRun(nil)
        }
        let due = WorkoutNoticeSelection.due(records: runs, enabledAt: enabledAt, now: now, notified: Set(notifiedIds), window: C.recentWindow)
        due.forEach { queue.add(PendingWorkout(activityId: $0.activityId, end: $0.end)) }
        let pending = queue.items.count
        C.logger.info("corridas novas: \(due.count), pendentes: \(pending)")
        for item in queue.items {
            await deliver(item, container: container, queue: &queue)
        }
        queue.save(defaults: defaults)
    }

    private func deliver(_ item: PendingWorkout, container: ModelContainer, queue: inout PendingWorkoutQueue) async {
        let status = await Task.detached(priority: .utility) {
            WorkoutNotice.status(activityId: item.activityId, in: ModelContext(container))
        }.value
        switch status {
        case .ready(let content):
            if !notifiedIds.contains(content.activityId) {
                await scheduler.schedule(id: C.idPrefix + String(content.activityId), title: content.title, text: content.body, link: DeepLink.workoutURL(content.activityId), at: nil)
                rememberActivity(content.activityId)
                C.logger.info("aviso agendado, atividade \(content.activityId)")
            }
            queue.remove(activityId: item.activityId)
        case .unavailable:
            C.logger.info("atividade \(item.activityId) não vai ter nota, saiu da fila")
            rememberActivity(item.activityId)
            queue.remove(activityId: item.activityId)
        case .waiting:
            C.logger.info("atividade \(item.activityId) ainda sem nota")
        }
    }

    private func beginBackgroundTask(model: AppModel) {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: C.backgroundTaskName) { [weak self] in
            MainActor.assumeIsolated {
                C.logger.info("tempo em segundo plano acabou")
                model.cancelSync()
                BackgroundSync.scheduleWorkoutRetry()
                self?.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private var expectedRun: ExpectedRun? {
        defaults.data(forKey: C.expectedKey).flatMap { try? JSONDecoder().decode(ExpectedRun.self, from: $0) }
    }

    private func saveExpectedRun(_ run: ExpectedRun?) {
        defaults.set(run.flatMap { try? JSONEncoder().encode($0) }, forKey: C.expectedKey)
    }

    private var notifiedIds: [Int64] {
        (defaults.array(forKey: C.notifiedKey) as? [NSNumber])?.map(\.int64Value) ?? []
    }

    private func rememberActivity(_ id: Int64) {
        let ids = (notifiedIds + [id]).suffix(C.notifiedLimit)
        defaults.set(ids.map { NSNumber(value: $0) }, forKey: C.notifiedKey)
    }
}
