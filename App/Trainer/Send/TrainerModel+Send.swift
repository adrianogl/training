import Foundation
import GarminAPI
import Insights
import TrainingCore

extension TrainerModel {
    func sendItems(_ filter: TrainerSendFilter, settings: TrainerSendSettings) -> [TrainerSendItem] {
        guard let plan else { return [] }
        let days = (0..<TrainerSendConstants.windowDays).map { currentDay.adding(days: $0) }
        var items: [TrainerSendItem] = []
        for day in days {
            if filter.kinds.contains(.run), settings.runFromTrainer, let workout = plan.workouts.first(where: { $0.day == day }),
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
        return items
    }

    func staleSends(_ filter: TrainerSendFilter, items: [TrainerSendItem], store: TrainerSendStore) -> [(key: String, record: TrainerSentRecord)] {
        let records = store.records()
        let stale = TrainerSendBuilder.stale(
            records: records, current: Set(items.map(\.key)), kinds: filter.kinds,
            from: currentDay, through: currentDay.adding(days: TrainerSendConstants.windowDays - 1)
        )
        return records.filter { _, record in stale.contains(record) }.map { (key: $0.key, record: $0.value) }.sorted { $0.record.day < $1.record.day }
    }

    func autoSend(client: GarminAccountClient?) async {
        let store = TrainerSendStore()
        let settings = store.settings()
        guard let client, let filter = settings.auto else { return }
        let items = sendItems(filter, settings: settings)
        let stale = staleSends(filter, items: items, store: store)
        let records = store.records()
        guard !stale.isEmpty || items.contains(where: { TrainerSendBuilder.status($0, records: records) != .current }) else { return }
        _ = await TrainerSender.send(items, stale: stale, client: client, store: store)
    }
}
