import Foundation
import GarminAPI
import Storage
import SwiftData
import TrainingCore

extension SyncEngine {
    func upsertHeartRateZones(_ dto: HRZonesDTO, today: Day) throws {
        let sport = dto.sport ?? SyncConstants.defaultZonesSport
        var descriptor = FetchDescriptor<HeartRateZonesRecord>(predicate: #Predicate { $0.sport == sport })
        descriptor.fetchLimit = 1
        let record: HeartRateZonesRecord
        if let existing = try modelContext.fetch(descriptor).first {
            record = existing
        } else {
            record = HeartRateZonesRecord(sport: sport)
            modelContext.insert(record)
        }
        record.zone1Floor = dto.zone1Floor
        record.zone2Floor = dto.zone2Floor
        record.zone3Floor = dto.zone3Floor
        record.zone4Floor = dto.zone4Floor
        record.zone5Floor = dto.zone5Floor
        record.maxHeartRate = dto.maxHeartRateUsed
        record.lactateThresholdHeartRate = dto.lactateThresholdHeartRateUsed
        record.restingHeartRate = dto.restingHeartRateUsed
        record.updatedAt = .now
        if let threshold = dto.lactateThresholdHeartRateUsed {
            try recordThreshold(threshold, sport: sport, on: today, in: modelContext)
        }
        try modelContext.save()
    }
}
