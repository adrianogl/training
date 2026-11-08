import Foundation
import SwiftData

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
