import FITReader
import Foundation
import GarminAPI
import HealthImport
import RemoteSync
import Storage
import Sync
import SwiftData
import TrainingCore
import UserNotifications

extension StravaModel {
    private typealias I = StravaImportConstants

    func runCandidates(days: Int = StravaRunMatchingConstants.backfillDays) async throws -> [StravaRunCandidate] {
        guard let client = link?() else { throw StravaLinkError.notConnected }
        let current = now()
        let after = current.addingTimeInterval(-Double(days) * StravaConstants.secondsPerDay)
        let runs = try await client.runs(after: after, before: current)
        let ignored = Set(ids(I.ignoredKey))
        return StravaRunMatching.unmatched(runs, existing: existingRuns(since: after.addingTimeInterval(-StravaRunMatchingConstants.window)))
            .filter { !ignored.contains($0.id) }
            .sorted { $0.start > $1.start }
    }

    func importRuns(_ runs: [StravaRunCandidate]) async throws -> Int {
        guard let client = link?() else { throw StravaLinkError.notConnected }
        let bounds = heartRateBounds()
        var dtos: [ActivityDTO] = []
        var summaries: [Int64: FITSummary] = [:]
        var failure: (any Error)?
        for run in runs {
            do {
                let streams = try await client.streams(stravaId: run.id)
                let dto = StravaRunMapping.activity(run, resting: bounds.resting, maximum: bounds.maximum)
                dtos.append(dto)
                summaries[dto.activityId] = StravaRunMapping.summary(streams)
            } catch {
                failure = error
                break
            }
        }
        if !dtos.isEmpty {
            let engine = SyncEngine(source: StravaRunSource(summaries: summaries), container: container, today: { Day.today() })
            let ids = try await engine.importExternalRuns(dtos)
            await clearNotifications(runs.filter { summaries[StravaActivityId.make($0.id)] != nil }.map(\.id))
            await imported?(ids.isEmpty ? Set(dtos.map(\.activityId)) : ids)
        }
        if dtos.isEmpty, let failure { throw failure }
        return dtos.count
    }

    func ignore(_ runIds: [Int64]) async {
        remember(runIds, key: I.ignoredKey)
        await clearNotifications(runIds)
    }

    func handleNotification(action: String, runId: Int64) async {
        switch action {
        case I.importAction:
            guard let run = try? await runCandidates(days: StravaRunMatchingConstants.recentDays).first(where: { $0.id == runId }) else { return }
            _ = try? await importRuns([run])
        case I.ignoreAction:
            await ignore([runId])
        default:
            break
        }
    }

    func notifyNewRuns() async {
        guard status.connected, let runs = try? await runCandidates(days: StravaRunMatchingConstants.recentDays) else { return }
        let notified = Set(ids(I.notifiedKey))
        let fresh = runs.filter { !notified.contains($0.id) }.prefix(I.recentNotifyLimit)
        guard !fresh.isEmpty else { return }
        registerCategory()
        for run in fresh {
            let content = UNMutableNotificationContent()
            content.title = StravaImportText.notificationTitle
            content.body = StravaImportText.notificationBody(run)
            content.sound = .default
            content.categoryIdentifier = I.category
            content.userInfo = [I.runIdKey: run.id, BackgroundConstants.deepLinkUserInfoKey: I.workoutsLink]
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: I.notificationPrefix + String(run.id), content: content, trigger: nil))
        }
        remember(fresh.map(\.id), key: I.notifiedKey)
    }

    func registerCategory() {
        let category = UNNotificationCategory(
            identifier: I.category,
            actions: [
                UNNotificationAction(identifier: I.importAction, title: StravaImportText.importButton),
                UNNotificationAction(identifier: I.ignoreAction, title: StravaImportText.ignoreButton, options: [.destructive]),
            ],
            intentIdentifiers: []
        )
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { existing in
            center.setNotificationCategories(existing.filter { $0.identifier != I.category }.union([category]))
        }
    }

    private func clearNotifications(_ runIds: [Int64]) async {
        let ids = runIds.map { I.notificationPrefix + String($0) }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func ids(_ key: String) -> [Int64] {
        (defaults.array(forKey: key) as? [NSNumber])?.map(\.int64Value) ?? []
    }

    private func remember(_ runIds: [Int64], key: String) {
        let merged = Array((ids(key) + runIds).reduce(into: [Int64]()) { if !$0.contains($1) { $0.append($1) } }.suffix(I.ledgerLimit))
        defaults.set(merged.map(NSNumber.init(value:)), forKey: key)
    }

    private func heartRateBounds() -> (resting: Double?, maximum: Double?) {
        let zones = try? runningZonesRecord(in: container.mainContext)
        return (zones?.restingHeartRate.map(Double.init), zones?.maxHeartRate.map(Double.init))
    }

    private func existingRuns(since start: Date) -> [(start: Date, meters: Double)] {
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= start })
        return ((try? container.mainContext.fetch(descriptor)) ?? [])
            .filter { ActivityTypeKey.isRun($0.typeKey) }
            .map { ($0.start, $0.distance ?? 0) }
    }
}
