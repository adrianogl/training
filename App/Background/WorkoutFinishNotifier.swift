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
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    private weak var model: AppModel?

    init(defaults: UserDefaults? = nil) {
        self.fixedDefaults = defaults
    }

    private var defaults: UserDefaults { fixedDefaults ?? AccountScope.current.defaults }

    var enabled: Bool { defaults.object(forKey: C.enabledKey) as? Bool ?? C.defaultEnabled }

    private var enabledAt: Date? { defaults.object(forKey: C.enabledAtKey) as? Date }

    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
    }

    func start(model: AppModel) {
        guard enabled, HKHealthStore.isHealthDataAvailable() else { return }
        self.model = model
        if enabledAt == nil {
            defaults.set(Date.now, forKey: C.enabledAtKey)
            C.logger.info("aviso ligado, enabledAt gravado")
        }
        let type = HKObjectType.workoutType()
        if !observing {
            observing = true
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                nonisolated(unsafe) let completion = completion
                if let error {
                    C.logger.error("observer com erro: \(error.localizedDescription, privacy: .public)")
                    completion()
                    return
                }
                Task { @MainActor in
                    C.logger.info("observer disparou")
                    if let self, let model = self.model { await self.refresh(model: model) }
                    completion()
                }
            }
            store.execute(query)
        }
        store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, error in
            if let error { C.logger.error("background delivery falhou: \(error.localizedDescription, privacy: .public)") }
        }
    }

    func detach() {
        model = nil
        store.disableBackgroundDelivery(for: HKObjectType.workoutType()) { _, _ in }
    }

    func stop() {
        defaults.removeObject(forKey: C.enabledAtKey)
        store.disableBackgroundDelivery(for: HKObjectType.workoutType()) { _, _ in }
    }

    func refresh(model: AppModel) async {
        guard enabled, let enabledAt else { return }
        guard !processing else {
            rerun = true
            return
        }
        processing = true
        defer { processing = false }
        repeat {
            rerun = false
            await process(model: model, enabledAt: enabledAt)
        } while rerun
    }

    private func process(model: AppModel, enabledAt: Date) async {
        let now = Date.now
        let workouts = await finishedRuns()
        let due = WorkoutNoticeSelection.due(workouts: workouts, enabledAt: enabledAt, now: now, notified: notifiedWorkouts, window: C.recentWindow)
        var queue = PendingWorkoutQueue.load(defaults: defaults)
        due.forEach { queue.add(PendingWorkout(id: $0.id, start: $0.start, end: $0.end)) }
        queue.prune(now: now, lifetime: C.recentWindow)
        queue.save(defaults: defaults)
        C.logger.info("corridas recentes: \(workouts.count), novas: \(due.count), pendentes: \(queue.items.count)")
        guard !queue.items.isEmpty else { return }

        beginBackgroundTask(model: model)
        defer { endBackgroundTask() }
        C.logger.info("sync leve começou")
        let synced = await model.syncNow(.workoutFinished)
        C.logger.info("sync leve terminou, ok: \(synced)")
        for item in queue.items {
            await deliver(item, container: model.container, queue: &queue)
        }
        queue.save(defaults: defaults)
        await model.strava.sendPending()
        guard !queue.items.isEmpty else { return }
        BackgroundSync.scheduleWorkoutRetry()
        C.logger.info("aviso adiado, pendentes: \(queue.items.count)")
    }

    private func deliver(_ item: PendingWorkout, container: ModelContainer, queue: inout PendingWorkoutQueue) async {
        let content = await Task.detached(priority: .utility) {
            WorkoutNotice.content(start: item.start, in: ModelContext(container))
        }.value
        guard let content else {
            C.logger.info("treino \(item.id.uuidString, privacy: .public) ainda sem nota")
            return
        }
        if !notifiedIds.contains(content.activityId) {
            await scheduler.schedule(id: C.idPrefix + String(content.activityId), title: content.title, text: content.body, link: C.deepLink, at: nil)
            rememberActivity(content.activityId)
            C.logger.info("aviso agendado, atividade \(content.activityId)")
        }
        rememberWorkout(item.id)
        queue.remove(id: item.id)
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

    private func finishedRuns() async -> [FinishedWorkout] {
        let window = HKQuery.predicateForSamples(withStart: Date.now.addingTimeInterval(-C.recentWindow), end: nil)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [window, HKQuery.predicateForWorkouts(with: .running)])
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { C.logger.error("consulta de treinos falhou: \(error.localizedDescription, privacy: .public)") }
                let workouts = (samples as? [HKWorkout] ?? []).map { FinishedWorkout(id: $0.uuid, start: $0.startDate, end: $0.endDate) }
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    private var notifiedIds: [Int64] {
        (defaults.array(forKey: C.notifiedKey) as? [NSNumber])?.map(\.int64Value) ?? []
    }

    private var notifiedWorkouts: Set<UUID> {
        Set((defaults.stringArray(forKey: C.notifiedWorkoutsKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    private func rememberActivity(_ id: Int64) {
        let ids = (notifiedIds + [id]).suffix(C.notifiedLimit)
        defaults.set(ids.map { NSNumber(value: $0) }, forKey: C.notifiedKey)
    }

    private func rememberWorkout(_ id: UUID) {
        let ids = ((defaults.stringArray(forKey: C.notifiedWorkoutsKey) ?? []) + [id.uuidString]).suffix(C.notifiedLimit)
        defaults.set(Array(ids), forKey: C.notifiedWorkoutsKey)
    }
}
