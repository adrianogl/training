import Foundation
import SwiftData

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
    public var samplesData: Data? = nil
    public var routeData: Data? = nil
    public var fitProcessed: Bool = false
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
        self.updatedAt = updatedAt
    }
}
