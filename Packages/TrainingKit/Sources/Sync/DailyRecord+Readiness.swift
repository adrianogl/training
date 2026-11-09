import Metrics
import Storage

public extension DailyRecord {
    func readinessInput(acuteChronic: Double?) -> ReadinessInput {
        var baseline: HRVBaseline?
        if let lowUpper = hrvLowUpper, let balancedLow = hrvBalancedLow, let balancedUpper = hrvBalancedUpper {
            baseline = HRVBaseline(lowUpper: lowUpper, balancedLow: balancedLow, balancedUpper: balancedUpper)
        }
        return ReadinessInput(
            hrvLastNight: hrvLastNight,
            hrvBaseline: baseline,
            sleepScore: sleepScore.map(Double.init),
            bodyBatteryMorningMax: bodyBatteryMorningMax.map(Double.init),
            acuteChronic: acuteChronic
        )
    }
}
