import Foundation
import GarminAPI
import TrainingCore

struct TrainerSendResult: Equatable {
    var sent = 0
    var removed = 0
    var failed = 0
    var firstError: String?
}

@MainActor
enum TrainerSender {
    static func send(_ items: [TrainerSendItem], stale: [(key: String, record: TrainerSentRecord)], client: GarminAccountClient, store: TrainerSendStore) async -> TrainerSendResult {
        await send(
            items, stale: stale, store: store,
            create: { try await GarminPlannedUpload.create(client: client, body: $0.payload, day: $0.day) },
            remove: { try await GarminPlannedUpload.delete(client: client, workoutId: $0) }
        )
    }

    static func send(
        _ items: [TrainerSendItem], stale: [(key: String, record: TrainerSentRecord)], store: TrainerSendStore,
        create: (TrainerSendItem) async throws -> Int64, remove: (Int64) async throws -> Void
    ) async -> TrainerSendResult {
        var result = TrainerSendResult()
        for entry in stale {
            do {
                try await remove(entry.record.workoutId)
                store.remove(key: entry.key)
                result.removed += 1
            } catch {
                result.failed += 1
                if result.firstError == nil { result.firstError = TrainerSendText.errorReason(error) }
            }
        }
        let records = store.records()
        for item in items where TrainerSendBuilder.status(item, records: records) != .current {
            do {
                if let previous = records[item.key] {
                    try await remove(previous.workoutId)
                    store.remove(key: item.key)
                }
                let id = try await create(item)
                store.record(
                    TrainerSentRecord(
                        workoutId: id, signature: item.signature, day: item.day.iso, kind: item.kind,
                        dayAdjust: item.dayAdjust, heatShare: item.heatShare, title: item.kind == .run ? item.title : nil
                    ),
                    key: item.key
                )
                result.sent += 1
            } catch {
                result.failed += 1
                if result.firstError == nil { result.firstError = TrainerSendText.errorReason(error) }
            }
        }
        IncludedHeatStore(defaults: store.defaults).absorb(store.records())
        return result
    }
}
