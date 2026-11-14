import Foundation
import HealthKit
import SwiftData

@MainActor final class WorkoutFinishNotifier {
    static let shared = WorkoutFinishNotifier()

    private typealias C = WorkoutNoticeConstants

    private struct FinishedRun: Sendable {
        let start: Date
    }

    private let store = HKHealthStore()
    private let defaults: UserDefaults
    private let scheduler = UserNotificationScheduler()
    private var observing = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var enabled: Bool { defaults.object(forKey: C.enabledKey) as? Bool ?? C.defaultEnabled }

    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
    }

    func start(model: AppModel) {
        guard enabled, HKHealthStore.isHealthDataAvailable() else { return }
        let type = HKObjectType.workoutType()
        if !observing {
            observing = true
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                nonisolated(unsafe) let completion = completion
                guard error == nil else { completion(); return }
                Task { @MainActor in
                    await self?.handleNewWorkouts(model: model)
                    completion()
                }
            }
            store.execute(query)
        }
        store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
    }

    func stop() {
        store.disableBackgroundDelivery(for: HKObjectType.workoutType()) { _, _ in }
    }

    private func handleNewWorkouts(model: AppModel) async {
        let runs = await newRuns()
        guard enabled, !runs.isEmpty else { return }
        await model.syncNow(.workoutFinished)
        let container = model.container
        for run in runs {
            let content = await Task.detached(priority: .utility) {
                WorkoutNotice.content(start: run.start, in: ModelContext(container))
            }.value
            guard let content, !notifiedIds.contains(content.activityId) else { continue }
            await scheduler.schedule(id: C.idPrefix + String(content.activityId), title: content.title, text: content.body, link: C.deepLink, at: nil)
            remember(content.activityId)
        }
    }

    private func newRuns() async -> [FinishedRun] {
        let stored = defaults.data(forKey: C.anchorKey)
        let anchor = stored.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
        let predicate = HKQuery.predicateForSamples(withStart: Date.now.addingTimeInterval(-C.recentWindow), end: nil)
        let (runs, next): ([FinishedRun], Data?) = await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(type: HKObjectType.workoutType(), predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { _, samples, _, newAnchor, _ in
                let runs = (samples ?? [])
                    .compactMap { $0 as? HKWorkout }
                    .filter { $0.workoutActivityType == .running }
                    .map { FinishedRun(start: $0.startDate) }
                let data = newAnchor.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
                continuation.resume(returning: (runs, data))
            }
            store.execute(query)
        }
        if let next { defaults.set(next, forKey: C.anchorKey) }
        return stored == nil ? [] : runs
    }

    private var notifiedIds: [Int64] {
        (defaults.array(forKey: C.notifiedKey) as? [NSNumber])?.map(\.int64Value) ?? []
    }

    private func remember(_ id: Int64) {
        let ids = (notifiedIds + [id]).suffix(C.notifiedLimit)
        defaults.set(ids.map { NSNumber(value: $0) }, forKey: C.notifiedKey)
    }
}
