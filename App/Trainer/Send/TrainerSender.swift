import Foundation
import GarminAPI
import TrainingCore

struct TrainerSendResult: Equatable {
    var sent = 0
    var removed = 0
    var failed = 0
}

@MainActor
enum TrainerSender {
    static func send(_ items: [TrainerSendItem], stale: [(key: String, record: TrainerSentRecord)], client: GarminAccountClient, store: TrainerSendStore) async -> TrainerSendResult {
        var result = TrainerSendResult()
        for entry in stale {
            try? await GarminPlannedUpload.delete(client: client, workoutId: entry.record.workoutId)
            store.remove(key: entry.key)
            result.removed += 1
        }
        let records = store.records()
        for item in items where TrainerSendBuilder.status(item, records: records) != .current {
            do {
                if let previous = records[item.key] {
                    try? await GarminPlannedUpload.delete(client: client, workoutId: previous.workoutId)
                }
                let id = try await GarminPlannedUpload.create(client: client, body: item.payload, day: item.day)
                store.record(TrainerSentRecord(workoutId: id, signature: item.signature, day: item.day.iso, kind: item.kind), key: item.key)
                result.sent += 1
            } catch {
                result.failed += 1
            }
        }
        return result
    }
}
