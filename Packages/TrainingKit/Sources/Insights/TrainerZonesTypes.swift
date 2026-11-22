import Foundation

public struct TrainerZoneBand: Equatable, Sendable {
    public let zone: Int
    public let heartRateLow: Int?
    public let heartRateHigh: Int?
    public let paceLow: Double?
    public let paceHigh: Double?
}
