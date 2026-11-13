import Foundation
import SwiftData

extension SchemaV5 {
    @Model
    public final class DailyRecord {
        public var day: String = ""
        public var restingHR: Int? = nil
        public var stressAvg: Int? = nil
        public var bodyBatteryMorningMax: Int? = nil
        public var bodyBatteryMin: Int? = nil
        public var bodyBatteryMax: Int? = nil
        public var respirationAvg: Double? = nil
        public var hrvLastNight: Double? = nil
        public var hrvWeekly: Double? = nil
        public var hrvStatus: String? = nil
        public var hrvLowUpper: Double? = nil
        public var hrvBalancedLow: Double? = nil
        public var hrvBalancedUpper: Double? = nil
        public var sleepSeconds: Int? = nil
        public var sleepDeepSeconds: Int? = nil
        public var sleepLightSeconds: Int? = nil
        public var sleepRemSeconds: Int? = nil
        public var sleepAwakeSeconds: Int? = nil
        public var sleepScore: Int? = nil
        public var sleepEndGMT: Int64? = nil
        public var readinessScore: Int? = nil
        public var readinessPartial: Bool = false
        public var updatedAt: Date = Date.now

        public init(
            day: String,
            restingHR: Int? = nil,
            stressAvg: Int? = nil,
            bodyBatteryMorningMax: Int? = nil,
            bodyBatteryMin: Int? = nil,
            bodyBatteryMax: Int? = nil,
            respirationAvg: Double? = nil,
            hrvLastNight: Double? = nil,
            hrvWeekly: Double? = nil,
            hrvStatus: String? = nil,
            hrvLowUpper: Double? = nil,
            hrvBalancedLow: Double? = nil,
            hrvBalancedUpper: Double? = nil,
            sleepSeconds: Int? = nil,
            sleepDeepSeconds: Int? = nil,
            sleepLightSeconds: Int? = nil,
            sleepRemSeconds: Int? = nil,
            sleepAwakeSeconds: Int? = nil,
            sleepScore: Int? = nil,
            sleepEndGMT: Int64? = nil,
            readinessScore: Int? = nil,
            readinessPartial: Bool = false,
            updatedAt: Date = .now
        ) {
            self.day = day
            self.restingHR = restingHR
            self.stressAvg = stressAvg
            self.bodyBatteryMorningMax = bodyBatteryMorningMax
            self.bodyBatteryMin = bodyBatteryMin
            self.bodyBatteryMax = bodyBatteryMax
            self.respirationAvg = respirationAvg
            self.hrvLastNight = hrvLastNight
            self.hrvWeekly = hrvWeekly
            self.hrvStatus = hrvStatus
            self.hrvLowUpper = hrvLowUpper
            self.hrvBalancedLow = hrvBalancedLow
            self.hrvBalancedUpper = hrvBalancedUpper
            self.sleepSeconds = sleepSeconds
            self.sleepDeepSeconds = sleepDeepSeconds
            self.sleepLightSeconds = sleepLightSeconds
            self.sleepRemSeconds = sleepRemSeconds
            self.sleepAwakeSeconds = sleepAwakeSeconds
            self.sleepScore = sleepScore
            self.sleepEndGMT = sleepEndGMT
            self.readinessScore = readinessScore
            self.readinessPartial = readinessPartial
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class ActivityRecord {
        public var activityId: Int64 = 0
        public var typeKey: String = ""
        public var name: String = ""
        public var start: Date = Date.distantPast
        public var locationName: String? = nil
        public var distance: Double? = nil
        public var duration: Double? = nil
        public var movingDuration: Double? = nil
        public var trainingEffectLabel: String? = nil
        public var averageHR: Double? = nil
        public var maxHR: Double? = nil
        public var activityTrainingLoad: Double? = nil
        public var aerobicTrainingEffect: Double? = nil
        public var anaerobicTrainingEffect: Double? = nil
        public var averageRunningCadenceInStepsPerMinute: Double? = nil
        public var avgGroundContactTime: Double? = nil
        public var avgVerticalOscillation: Double? = nil
        public var avgVerticalRatio: Double? = nil
        public var avgStrideLength: Double? = nil
        public var avgPower: Double? = nil
        public var elevationGain: Double? = nil
        public var elevationLoss: Double? = nil
        public var fastestSplit_1000: Double? = nil
        public var fastestSplit_5000: Double? = nil
        public var pr: Bool? = nil
        public var zoneSeconds: [Double] = []
        public var vo2max: Double? = nil
        public var recoveryMinutes: Int? = nil
        public var performanceCondition: Int? = nil
        @Attribute(.externalStorage) public var samplesData: Data? = nil
        @Attribute(.externalStorage) public var routeData: Data? = nil
        public var fitProcessed: Bool = false
        public var localDay: String? = nil
        public var processingVersion: Int = 0
        public var workoutName: String? = nil
        public var structureData: Data? = nil
        public var narrativeData: Data? = nil
        public var fitTransientFailures: Int = 0
        public var thresholdZoneSeconds: [Double] = []
        public var thresholdUsed: Int? = nil
        public var fitThresholdHeartRate: Int? = nil
        public var watchZoneFloors: [Int] = []
        public var scoreValue: Int? = nil
        public var scoreKey: String? = nil
        @Attribute(.externalStorage) public var scoreData: Data? = nil
        public var updatedAt: Date = Date.now

        public init(
            activityId: Int64,
            typeKey: String = "",
            name: String = "",
            start: Date = Date.distantPast,
            locationName: String? = nil,
            distance: Double? = nil,
            duration: Double? = nil,
            movingDuration: Double? = nil,
            trainingEffectLabel: String? = nil,
            averageHR: Double? = nil,
            maxHR: Double? = nil,
            activityTrainingLoad: Double? = nil,
            aerobicTrainingEffect: Double? = nil,
            anaerobicTrainingEffect: Double? = nil,
            averageRunningCadenceInStepsPerMinute: Double? = nil,
            avgGroundContactTime: Double? = nil,
            avgVerticalOscillation: Double? = nil,
            avgVerticalRatio: Double? = nil,
            avgStrideLength: Double? = nil,
            avgPower: Double? = nil,
            elevationGain: Double? = nil,
            elevationLoss: Double? = nil,
            fastestSplit_1000: Double? = nil,
            fastestSplit_5000: Double? = nil,
            pr: Bool? = nil,
            zoneSeconds: [Double] = [],
            vo2max: Double? = nil,
            recoveryMinutes: Int? = nil,
            performanceCondition: Int? = nil,
            samplesData: Data? = nil,
            routeData: Data? = nil,
            fitProcessed: Bool = false,
            localDay: String? = nil,
            processingVersion: Int = 0,
            workoutName: String? = nil,
            structureData: Data? = nil,
            narrativeData: Data? = nil,
            fitTransientFailures: Int = 0,
            thresholdZoneSeconds: [Double] = [],
            thresholdUsed: Int? = nil,
            fitThresholdHeartRate: Int? = nil,
            watchZoneFloors: [Int] = [],
            scoreValue: Int? = nil,
            scoreKey: String? = nil,
            scoreData: Data? = nil,
            updatedAt: Date = .now
        ) {
            self.activityId = activityId
            self.typeKey = typeKey
            self.name = name
            self.start = start
            self.locationName = locationName
            self.distance = distance
            self.duration = duration
            self.movingDuration = movingDuration
            self.trainingEffectLabel = trainingEffectLabel
            self.averageHR = averageHR
            self.maxHR = maxHR
            self.activityTrainingLoad = activityTrainingLoad
            self.aerobicTrainingEffect = aerobicTrainingEffect
            self.anaerobicTrainingEffect = anaerobicTrainingEffect
            self.averageRunningCadenceInStepsPerMinute = averageRunningCadenceInStepsPerMinute
            self.avgGroundContactTime = avgGroundContactTime
            self.avgVerticalOscillation = avgVerticalOscillation
            self.avgVerticalRatio = avgVerticalRatio
            self.avgStrideLength = avgStrideLength
            self.avgPower = avgPower
            self.elevationGain = elevationGain
            self.elevationLoss = elevationLoss
            self.fastestSplit_1000 = fastestSplit_1000
            self.fastestSplit_5000 = fastestSplit_5000
            self.pr = pr
            self.zoneSeconds = zoneSeconds
            self.vo2max = vo2max
            self.recoveryMinutes = recoveryMinutes
            self.performanceCondition = performanceCondition
            self.samplesData = samplesData
            self.routeData = routeData
            self.fitProcessed = fitProcessed
            self.localDay = localDay
            self.processingVersion = processingVersion
            self.workoutName = workoutName
            self.structureData = structureData
            self.narrativeData = narrativeData
            self.fitTransientFailures = fitTransientFailures
            self.thresholdZoneSeconds = thresholdZoneSeconds
            self.thresholdUsed = thresholdUsed
            self.fitThresholdHeartRate = fitThresholdHeartRate
            self.watchZoneFloors = watchZoneFloors
            self.scoreValue = scoreValue
            self.scoreKey = scoreKey
            self.scoreData = scoreData
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class RaceRecord {
        public var id: UUID = UUID()
        public var name: String = ""
        public var day: String = ""
        public var startTime: String? = nil
        public var distance: Double = 0
        public var goalSeconds: Double? = nil
        public var priority: String = "C"
        public var city: String? = nil
        public var gpxData: Data? = nil
        public var manualPacesData: Data? = nil
        public var customLabelsData: Data? = nil
        public var resultActivityId: Int64? = nil
        public var frozenTargetSeconds: Double? = nil
        public var frozenTargetDay: String? = nil
        public var manuallyUnlinked: Bool = false
        public var updatedAt: Date = Date.now

        public init(
            id: UUID = UUID(),
            name: String,
            day: String,
            distance: Double,
            startTime: String? = nil,
            goalSeconds: Double? = nil,
            priority: RacePriority = .c,
            city: String? = nil,
            gpxData: Data? = nil,
            manualPacesData: Data? = nil,
            customLabelsData: Data? = nil,
            resultActivityId: Int64? = nil,
            frozenTargetSeconds: Double? = nil,
            frozenTargetDay: String? = nil,
            manuallyUnlinked: Bool = false,
            updatedAt: Date = .now
        ) {
            self.id = id
            self.name = name
            self.day = day
            self.distance = distance
            self.startTime = startTime
            self.goalSeconds = goalSeconds
            self.priority = priority.rawValue
            self.city = city
            self.gpxData = gpxData
            self.manualPacesData = manualPacesData
            self.customLabelsData = customLabelsData
            self.resultActivityId = resultActivityId
            self.frozenTargetSeconds = frozenTargetSeconds
            self.frozenTargetDay = frozenTargetDay
            self.manuallyUnlinked = manuallyUnlinked
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class SyncState {
        public var firstLoadCompleted: Bool = false
        public var lastSync: Date? = nil
        public var lastActivityStart: Date? = nil
        public var resumeDailyFrom: String? = nil
        public var resumeHRVFrom: String? = nil
        public var resumeSleepFrom: String? = nil
        public var resumeBodyBatteryFrom: String? = nil
        public var resumeActivityStart: Int? = nil
        public var readinessVersion: Int = 0

        public init(
            firstLoadCompleted: Bool = false,
            lastSync: Date? = nil,
            lastActivityStart: Date? = nil,
            resumeDailyFrom: String? = nil,
            resumeHRVFrom: String? = nil,
            resumeSleepFrom: String? = nil,
            resumeBodyBatteryFrom: String? = nil,
            resumeActivityStart: Int? = nil,
            readinessVersion: Int = 0
        ) {
            self.firstLoadCompleted = firstLoadCompleted
            self.lastSync = lastSync
            self.lastActivityStart = lastActivityStart
            self.resumeDailyFrom = resumeDailyFrom
            self.resumeHRVFrom = resumeHRVFrom
            self.resumeSleepFrom = resumeSleepFrom
            self.resumeBodyBatteryFrom = resumeBodyBatteryFrom
            self.resumeActivityStart = resumeActivityStart
            self.readinessVersion = readinessVersion
        }

        public func clearResumeCursors() {
            resumeDailyFrom = nil
            resumeHRVFrom = nil
            resumeSleepFrom = nil
            resumeBodyBatteryFrom = nil
            resumeActivityStart = nil
        }
    }

    @Model
    public final class HeartRateZonesRecord {
        public var sport: String = "running"
        public var zone1Floor: Int? = nil
        public var zone2Floor: Int? = nil
        public var zone3Floor: Int? = nil
        public var zone4Floor: Int? = nil
        public var zone5Floor: Int? = nil
        public var maxHeartRate: Int? = nil
        public var lactateThresholdHeartRate: Int? = nil
        public var restingHeartRate: Int? = nil
        public var updatedAt: Date = Date.now

        public init(
            sport: String = "running",
            zone1Floor: Int? = nil,
            zone2Floor: Int? = nil,
            zone3Floor: Int? = nil,
            zone4Floor: Int? = nil,
            zone5Floor: Int? = nil,
            maxHeartRate: Int? = nil,
            lactateThresholdHeartRate: Int? = nil,
            restingHeartRate: Int? = nil,
            updatedAt: Date = .now
        ) {
            self.sport = sport
            self.zone1Floor = zone1Floor
            self.zone2Floor = zone2Floor
            self.zone3Floor = zone3Floor
            self.zone4Floor = zone4Floor
            self.zone5Floor = zone5Floor
            self.maxHeartRate = maxHeartRate
            self.lactateThresholdHeartRate = lactateThresholdHeartRate
            self.restingHeartRate = restingHeartRate
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class ThresholdHistoryRecord {
        public var sport: String = ""
        public var day: String = ""
        public var heartRate: Int = 0

        public init(sport: String, day: String, heartRate: Int) {
            self.sport = sport
            self.day = day
            self.heartRate = heartRate
        }
    }

    @Model
    public final class RaceDecisionRecord {
        public var activityId: Int64 = 0
        public var decision: String = ""
        public var decidedAt: Date = Date.now

        public var raceDecision: RaceDecision? {
            get { RaceDecision(rawValue: decision) }
            set { decision = newValue?.rawValue ?? "" }
        }

        public init(activityId: Int64, decision: RaceDecision, decidedAt: Date = .now) {
            self.activityId = activityId
            self.decision = decision.rawValue
            self.decidedAt = decidedAt
        }
    }
}
