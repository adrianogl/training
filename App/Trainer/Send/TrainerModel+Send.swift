import Foundation
import GarminAPI
import Insights
import MFIT
import TrainingCore

extension TrainerModel {
    func sendItems(_ filter: TrainerSendFilter, settings: TrainerSendSettings) -> [TrainerSendItem] {
        let days = (0..<TrainerSendConstants.windowDays).map { currentDay.adding(days: $0) }
        var items: [TrainerSendItem] = []
        for day in days {
            if filter.kinds.contains(.run), settings.runFromTrainer, let workout = plan?.workouts.first(where: { $0.day == day }),
               let item = TrainerSendBuilder.runItem(workout) {
                items.append(item)
            }
            if filter.kinds.contains(.strength) {
                for session in trainerSessions(on: day) {
                    if let workout = strengthWorkout(sessionId: session.id, day: day),
                       let item = TrainerSendBuilder.strengthItem(workout, sessionId: session.id, day: day) {
                        items.append(item)
                    }
                }
            }
        }
        if filter.kinds.contains(.strength), settings.sendsMFIT, let program = StrengthProgramStore().load().program {
            let last = MFITSendBuilder.end(program, today: currentDay)
            if last >= currentDay {
                let workouts = StrengthSchedule().workouts(program, from: currentDay, through: last)
                items += MFITSendBuilder.items(workouts: workouts, replaced: replacesMFIT, catalogId: MFITSendBuilder.catalogId)
            }
        }
        return items.enumerated().sorted { ($0.element.day, $0.offset) < ($1.element.day, $1.offset) }.map(\.element)
    }

    private func staleLastDay(_ records: [String: TrainerSentRecord]) -> Day {
        let window = currentDay.adding(days: TrainerSendConstants.windowDays - 1)
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
        return await TrainerSender.send(items, stale: stale, client: client, store: TrainerSendStore())
    }

    func sendToAppleWatch(_ items: [TrainerSendItem], stale: [(key: String, record: TrainerSentRecord)]) async -> TrainerSendResult? {
        guard !isSendingToGarmin else { return nil }
        isSendingToGarmin = true
        defer { isSendingToGarmin = false }
        return await AppleWorkoutSender.send(items, stale: stale, store: TrainerSendStore())
    }

    func autoSend(client: GarminAccountClient?) async {
        let store = TrainerSendStore()
        let settings = store.settings()
        guard let client, let filter = settings.auto, !isSendingToGarmin else { return }
        let items = sendItems(filter, settings: settings)
        let stale = staleSends(filter, items: items, store: store)
        let records = store.records()
        guard !stale.isEmpty || items.contains(where: { TrainerSendBuilder.status($0, records: records) != .current }) else { return }
        _ = await sendToGarmin(items, stale: stale, client: client)
    }
}
