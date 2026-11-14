import TrainingCore

struct DailySignal: Equatable, Sendable {
    let day: Day
    let restingHeartRate: Int?
    let hrv: Double?
}

struct OverloadAlert: Equatable {
    let days: Int
    let restingNow: Int?
    let restingBase: Int?
    let hrvNow: Int?
    let hrvBase: Int?
    let ratio: Double?
    let restingHigh: Bool
    let hrvLow: Bool
    let loadHigh: Bool
}
