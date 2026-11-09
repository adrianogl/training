import Foundation
enum ReadinessConstants {
    static let hrvWeight = 0.35
    static let sleepWeight = 0.25
    static let bodyBatteryWeight = 0.20
    static let loadWeight = 0.20

    static let hrvLowEdgeScore = 60.0
    static let hrvBalancedTopScore = 100.0

    static let loadIdealLow = 0.8
    static let loadIdealHigh = 1.3
    static let loadZeroLow = 0.5
    static let loadZeroHigh = 1.8

    static let moderateThreshold = 40
    static let hardThreshold = 70

    static let bodyBatteryWindow: TimeInterval = 3 * 3600

    static let normalMinimumDays = 14
    static let normalWindowDays = 30
}
