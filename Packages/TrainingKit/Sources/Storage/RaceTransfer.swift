import Foundation
import SwiftData

public enum RaceTransfer {
    public static func export(_ races: [RaceRecord]) throws -> Data {
        let file = RaceTransferFile(
            version: RaceTransferConstants.currentVersion,
            races: races.map(RaceTransferItem.init)
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
        for item in file.races {
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
        return (inserted, updated, skipped)
    }
}

extension RaceTransferItem {
    init(_ race: RaceRecord) {
        self.init(
            id: race.id, name: race.name, day: race.day, startTime: race.startTime,
            distance: race.distance, goalSeconds: race.goalSeconds, priority: race.priority,
            city: race.city, gpxData: race.gpxData, manualPacesData: race.manualPacesData,
            customLabelsData: race.customLabelsData, resultActivityId: race.resultActivityId,
            updatedAt: race.updatedAt
        )
    }

    func makeRecord() -> RaceRecord {
        RaceRecord(
            id: id, name: name, day: day, distance: distance, startTime: startTime,
            goalSeconds: goalSeconds, priority: priority, city: city, gpxData: gpxData,
            manualPacesData: manualPacesData, customLabelsData: customLabelsData,
            resultActivityId: resultActivityId, updatedAt: updatedAt
        )
    }

    func apply(to race: RaceRecord) {
        race.name = name
        race.day = day
        race.startTime = startTime
        race.distance = distance
        race.goalSeconds = goalSeconds
        race.priority = priority
        race.city = city
        race.gpxData = gpxData
        race.manualPacesData = manualPacesData
        race.customLabelsData = customLabelsData
        race.resultActivityId = resultActivityId
        race.updatedAt = updatedAt
    }
}
