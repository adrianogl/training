import Foundation
import HealthKit
import UIKit

@MainActor final class SleepArrivalNotifier {
    static let shared = SleepArrivalNotifier()

    private typealias C = SleepArrivalConstants

    private let store = HKHealthStore()
    private let type = HKCategoryType(.sleepAnalysis)
    private var observing = false
    private var syncing = false
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid
    private weak var model: AppModel?

    func start(model: AppModel) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        self.model = model
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
                    await self?.sleepArrived()
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
        store.disableBackgroundDelivery(for: type) { _, _ in }
    }

    private func sleepArrived() async {
        guard let model else { return }
        let appActive = UIApplication.shared.applicationState == .active
        guard SleepArrivalPolicy.shouldSync(now: .now, calendar: .current, readinessComplete: model.todayReadinessComplete, appActive: appActive, syncing: syncing) else { return }
        syncing = true
        defer { syncing = false }
        beginBackgroundTask(model: model)
        defer { endBackgroundTask() }
        C.logger.info("sono chegou, sync começou")
        let synced = await model.syncNow(.background)
        await model.trainer.settleAutoAdjust()
        BackgroundSync.schedule(readinessComplete: model.todayReadinessComplete)
        C.logger.info("sync terminou, ok: \(synced), prontidão completa: \(model.todayReadinessComplete)")
    }

    private func beginBackgroundTask(model: AppModel) {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: C.backgroundTaskName) { [weak self] in
            MainActor.assumeIsolated {
                C.logger.info("tempo em segundo plano acabou")
                model.cancelSync()
                model.trainer.cancelAutoAdjust()
                self?.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
