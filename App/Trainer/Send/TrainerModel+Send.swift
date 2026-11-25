import Foundation
import GarminAPI
import Insights
import MFIT
import TrainingCore

extension TrainerModel {
    var sendLastDay: Day {
        let window = currentDay.adding(days: TrainerSendConstants.windowDays - 1)
        guard let plan, plan.endedOn == nil, let last = plan.workouts.map(\.day).max() else { return window }
        return max(window, last)
    }

    func sendItems(_ filter: TrainerSendFilter, settings: TrainerSendSettings) -> [TrainerSendItem] {
        let days = (0...max(0, currentDay.days(until: sendLastDay))).map { currentDay.adding(days: $0) }
        var items: [TrainerSendItem] = []
        let prefs = TrainerStrengthPrefsStore().load()
        let threshold = thresholdHeartRate
        let maxHeartRate = maxHeartRate
        let today = currentDay
        let cache = StrengthProgramStore().load()
        for day in days {
            if filter.kinds.contains(.run), settings.runFromTrainer, let workout = plan?.workouts.first(where: { $0.day == day }),
               let item = TrainerSendBuilder.runItem(
                   workout, entries: day == today ? todayEntries(for: workout) : nil, thresholdHeartRate: threshold, maxHeartRate: maxHeartRate
               ) {
                items.append(item)
            }
            if filter.kinds.contains(.strength), plan != nil {
                for session in trainerSessions(on: day) {
                    if let workout = strengthWorkout(sessionId: session.id, day: day, prefs: prefs, cache: cache),
                       let item = TrainerSendBuilder.strengthItem(workout, sessionId: session.id, day: day) {
                        items.append(item)
                    }
                }
            }
        }
        if filter.kinds.contains(.strength), settings.sendsMFIT, let program = cache.program {
            let last = MFITSendBuilder.end(program, today: currentDay)
            if last >= currentDay {
                let workouts = StrengthSchedule().workouts(program, from: currentDay, through: last)
                items += MFITSendBuilder.items(workouts: workouts, replaced: replacesMFIT, catalogId: MFITSendBuilder.catalogId)
            }
        }
        return items.enumerated().sorted { ($0.element.day, $0.offset) < ($1.element.day, $1.offset) }.map(\.element)
    }

    private func staleLastDay(_ records: [String: TrainerSentRecord]) -> Day {
        let window = sendLastDay
        let mfitDays = records.filter { $0.key.hasPrefix(TrainerSendConstants.mfitKeyPrefix) }.compactMap { Day(iso: $0.value.day) }
        return ([window] + mfitDays).max() ?? window
    }

    func staleSends(_ filter: TrainerSendFilter, items: [TrainerSendItem], store: TrainerSendStore) -> [(key: String, record: TrainerSentRecord)] {
        let records = store.records()
        let stale = TrainerSendBuilder.stale(
            records: records, current: Set(items.map(\.key)), kinds: filter.kinds,
            from: currentDay, through: staleLastDay(records)
        )
        return records.filter { _, record in stale.contains(record) }.map { (key: $0.key, record: $0.value) }.sorted { $0.record.day < $1.record.day }
    }

    func sendToGarmin(_ items: [TrainerSendItem], stale: [(key: String, record: TrainerSentRecord)], client: GarminAccountClient) async -> TrainerSendResult? {
        guard !isSendingToGarmin else { return nil }
        isSendingToGarmin = true
        defer { isSendingToGarmin = false }
        let store = TrainerSendStore()
        await cleanGarmin(client: client, store: store)
        let result = await TrainerSender.send(items, stale: stale, client: client, store: store)
        await refreshChangeWatch()
        await checkWatchPending()
        return result
    }

    func sendToAppleWatch(_ items: [TrainerSendItem], stale: [(key: String, record: TrainerSentRecord)]) async -> TrainerSendResult? {
        guard !isSendingToGarmin else { return nil }
        isSendingToGarmin = true
        defer { isSendingToGarmin = false }
        return await AppleWorkoutSender.send(items, stale: stale, store: TrainerSendStore())
    }

    func cleanGarmin(client: GarminAccountClient, store: TrainerSendStore) async {
        for id in store.orphans() {
            do {
                try await GarminPlannedUpload.delete(client: client, workoutId: id)
                store.clearOrphan(id)
            } catch {}
        }
        let last = currentDay.adding(days: TrainerSendConstants.legacyCleanupDays)
        guard let scheduled = try? await PlannedWorkouts.scheduledWorkouts(client: client, from: currentDay, through: last) else { return }
        let keys = Dictionary(store.records().map { ($0.value.workoutId, $0.key) }, uniquingKeysWith: { first, _ in first })
        for item in scheduled where item.title.hasPrefix(TrainerSendConstants.legacyNamePrefix) {
            guard (try? await GarminPlannedUpload.delete(client: client, workoutId: item.workoutId)) != nil else { continue }
            if let key = keys[item.workoutId] { store.remove(key: key) }
        }
    }

    func forgetDeletedOnGarmin(client: GarminAccountClient, store: TrainerSendStore = TrainerSendStore()) async {
        let upcoming = store.records().filter { Day(iso: $0.value.day).map { $0 >= currentDay } ?? false }
        let days = upcoming.values.compactMap { Day(iso: $0.day) }
        guard let first = days.min(), let last = days.max(),
              let scheduled = try? await PlannedWorkouts.scheduledWorkoutIds(client: client, from: first, through: last) else { return }
        for (key, record) in upcoming where !scheduled.contains(record.workoutId) {
            store.remove(key: key)
        }
    }

    func deletePlanAndSentWorkouts(client: GarminAccountClient?, appleWatch: Bool) async {
        let store = TrainerSendStore()
        let sent = TrainerSendBuilder.planRecords(store.records(), from: currentDay)
        deletePlan()
        guard !sent.isEmpty else { return }
        if appleWatch {
            _ = await sendToAppleWatch([], stale: sent)
        } else if let client {
            _ = await sendToGarmin([], stale: sent, client: client)
        }
    }

    var sendsToGarmin: Bool {
        WatchKind.stored(in: defaults) == .garmin && hasGarminAccount()
    }

    private var pendingFilter: (filter: TrainerSendFilter, settings: TrainerSendSettings) {
        let settings = TrainerSendStore(defaults: defaults).settings()
        return (settings.runFromTrainer ? .both : .strength, settings)
    }

    func pendingGarminSends() -> Int {
        let (filter, settings) = pendingFilter
        let records = TrainerSendStore(defaults: defaults).records()
        return sendItems(filter, settings: settings).filter { TrainerSendBuilder.status($0, records: records) != .current }.count
    }

    @discardableResult
    func sendPendingToGarmin(client: GarminAccountClient) async -> TrainerSendResult? {
        let (filter, settings) = pendingFilter
        let store = TrainerSendStore(defaults: defaults)
        await forgetDeletedOnGarmin(client: client, store: store)
        let items = sendItems(filter, settings: settings)
        return await sendToGarmin(items, stale: staleSends(filter, items: items, store: store), client: client)
    }

    func checkWatchPending() async {
        let tomorrow = currentDay.adding(days: 1)
        let store = TrainerSendStore(defaults: defaults)
        let enabled = sendsToGarmin
        let items = enabled ? sendItems(pendingFilter.filter, settings: store.settings()).filter { $0.day == tomorrow } : []
        await watchPendingNotifier.update(tomorrow: tomorrow, items: items, records: store.records(), enabled: enabled)
    }

    func autoSend(client: GarminAccountClient?) async {
        let store = TrainerSendStore()
        let settings = store.settings()
        guard let client, let filter = settings.auto, !isSendingToGarmin else { return }
        await forgetDeletedOnGarmin(client: client, store: store)
        let items = sendItems(filter, settings: settings)
        let stale = staleSends(filter, items: items, store: store)
        let records = store.records()
        guard !stale.isEmpty || items.contains(where: { TrainerSendBuilder.status($0, records: records) != .current }) else { return }
        _ = await sendToGarmin(items, stale: stale, client: client)
    }
}
