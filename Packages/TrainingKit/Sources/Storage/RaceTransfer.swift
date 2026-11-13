import Foundation
import SwiftData

public enum RaceTransfer {
    public static func export(_ races: [RaceRecord]) throws -> Data {
        let file = RaceTransferFile(
            version: RaceTransferConstants.currentVersion,
            races: races.filter { $0.deletedAt == nil }.map(RaceTransferItem.init)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(file)
    }

    public static func importRaces(
        _ data: Data,
        into context: ModelContext
    ) throws -> (inserted: Int, updated: Int, skipped: Int) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let probe = try decoder.decode(RaceTransferVersionProbe.self, from: data)
        guard probe.version == RaceTransferConstants.currentVersion else {
            throw RaceTransferError.unsupportedVersion(probe.version)
        }
        let file = try decoder.decode(RaceTransferFile.self, from: data)

        var inserted = 0, updated = 0, skipped = 0
        var order: [UUID] = []
        var newest: [UUID: RaceTransferItem] = [:]
        for item in file.races {
            guard let kept = newest[item.id] else {
                order.append(item.id)
                newest[item.id] = item
                continue
            }
            skipped += 1
            if item.updatedAt > kept.updatedAt { newest[item.id] = item }
        }
        for item in order.compactMap({ newest[$0] }) {
            let id = item.id
            var descriptor = FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                if item.updatedAt > existing.updatedAt {
                    item.apply(to: existing)
                    updated += 1
                } else {
                    skipped += 1
                }
            } else {
                context.insert(item.makeRecord())
                inserted += 1
            }
        }
        if inserted + updated > 0 {
            for state in try context.fetch(FetchDescriptor<SyncState>()) {
                state.remoteLastPush = nil
            }
        }
        return (inserted, updated, skipped)
    }
}

extension RaceTransferItem {
    public init(_ race: RaceRecord) {
        self.init(
            id: race.id, name: race.name, day: race.day, startTime: race.startTime,
            distance: race.distance, goalSeconds: race.goalSeconds, priority: race.priority,
            city: race.city, gpxData: race.gpxData, manualPacesData: race.manualPacesData,
            customLabelsData: race.customLabelsData, resultActivityId: race.resultActivityId,
            frozenTargetSeconds: race.frozenTargetSeconds, frozenTargetDay: race.frozenTargetDay,
            manuallyUnlinked: race.manuallyUnlinked, updatedAt: race.updatedAt
        )
    }

    public func makeRecord() -> RaceRecord {
        RaceRecord(
            id: id, name: name, day: day, distance: distance, startTime: startTime,
            goalSeconds: goalSeconds, priority: RacePriority(rawValue: priority) ?? .c, city: city, gpxData: gpxData,
            manualPacesData: manualPacesData, customLabelsData: customLabelsData,
            resultActivityId: resultActivityId, frozenTargetSeconds: frozenTargetSeconds,
            frozenTargetDay: frozenTargetDay,
            manuallyUnlinked: manuallyUnlinked ?? false, updatedAt: updatedAt
        )
    }

    public func apply(to race: RaceRecord) {
        race.name = name
        race.day = day
        race.startTime = startTime
        race.distance = distance
        race.goalSeconds = goalSeconds
        race.priorityLevel = RacePriority(rawValue: priority) ?? .c
        race.city = city
        race.gpxData = gpxData
        race.manualPacesData = manualPacesData
        race.customLabelsData = customLabelsData
        race.resultActivityId = resultActivityId
        race.frozenTargetSeconds = frozenTargetSeconds
        race.frozenTargetDay = frozenTargetDay
        race.manuallyUnlinked = manuallyUnlinked ?? race.manuallyUnlinked
        race.updatedAt = updatedAt
        race.deletedAt = nil
    }
}
