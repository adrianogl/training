import Foundation
import GarminAPI
import Storage
import SwiftData
import TrainingCore

extension SyncEngine {
    func upsertDaily(_ day: Day, apply: (DailyRecord) -> Void) throws {
        let key = day.iso
        var descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == key })
        descriptor.fetchLimit = 1
        let record: DailyRecord
        if let existing = try modelContext.fetch(descriptor).first {
            record = existing
        } else {
            record = DailyRecord(day: key)
            modelContext.insert(record)
        }
        apply(record)
        record.updatedAt = .now
    }

    func upsertActivity(_ dto: ActivityDTO) throws {
        let id = dto.activityId
        var descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == id })
        descriptor.fetchLimit = 1
        let record: ActivityRecord
        if let existing = try modelContext.fetch(descriptor).first {
            record = existing
        } else {
            record = ActivityRecord(activityId: id)
            modelContext.insert(record)
        }
        record.apply(dto)
        record.updatedAt = .now
    }
}

extension DailyRecord {
    func apply(_ dto: DailySummaryDTO) {
        restingHR = dto.restingHeartRate
        stressAvg = dto.avgStress
        bodyBatteryMin = dto.bodyBatteryMin
        bodyBatteryMax = dto.bodyBatteryMax
        respirationAvg = dto.avgRespiration
    }

    func apply(_ dto: HRVSummaryDTO) {
        hrvLastNight = dto.lastNightAvg
        hrvWeekly = dto.weeklyAvg
        hrvStatus = dto.status
        hrvLowUpper = dto.baselineLowUpper
        hrvBalancedLow = dto.baselineBalancedLow
        hrvBalancedUpper = dto.baselineBalancedUpper
    }

    func apply(_ dto: SleepDTO) {
        sleepSeconds = dto.sleepTimeSeconds
        sleepDeepSeconds = dto.deepSleepSeconds
        sleepLightSeconds = dto.lightSleepSeconds
        sleepRemSeconds = dto.remSleepSeconds
        sleepAwakeSeconds = dto.awakeSleepSeconds
        sleepScore = dto.overallScore
        sleepEndGMT = dto.sleepEndTimestampGMT
    }
}

extension ActivityRecord {
    func apply(_ dto: ActivityDTO) {
        typeKey = dto.typeKey ?? ""
        name = dto.activityName ?? ""
        if let local = dto.startTimeLocal, let parsed = ActivityTime.parseLocal(local) {
            start = parsed
        }
        if let local = dto.startTimeLocal, let day = ActivityTime.localDay(local) {
            localDay = day
        }
        locationName = dto.locationName
        distance = dto.distance
        duration = dto.duration
        movingDuration = dto.movingDuration
        trainingEffectLabel = dto.trainingEffectLabel
        averageHR = dto.averageHR
        maxHR = dto.maxHR
        activityTrainingLoad = dto.activityTrainingLoad
        aerobicTrainingEffect = dto.aerobicTrainingEffect
        anaerobicTrainingEffect = dto.anaerobicTrainingEffect
        averageRunningCadenceInStepsPerMinute = dto.averageRunningCadenceInStepsPerMinute
        avgGroundContactTime = dto.avgGroundContactTime
        avgVerticalOscillation = dto.avgVerticalOscillation
        avgVerticalRatio = dto.avgVerticalRatio
        avgStrideLength = dto.avgStrideLength
        avgPower = dto.avgPower
        elevationGain = dto.elevationGain
        elevationLoss = dto.elevationLoss
        fastestSplit_1000 = dto.fastestSplit_1000
        fastestSplit_5000 = dto.fastestSplit_5000
        pr = dto.pr
        zoneSeconds = dto.hrTimeInZone ?? []
    }
}
