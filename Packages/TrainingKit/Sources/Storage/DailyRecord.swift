import Foundation
import SwiftData

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
        self.readinessScore = readinessScore
        self.readinessPartial = readinessPartial
        self.updatedAt = updatedAt
    }
}
