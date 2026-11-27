import Foundation

enum TrainerZoneChartMode: Hashable {
    case pace, heartRate
}

struct TrainerZoneChartBand: Identifiable {
    let zone: Int
    let index: Int
    let low: Double
    let high: Double

    var id: String { "\(zone)-\(index)" }
}

struct TrainerZoneChartPoint: Identifiable {
    let zone: Int
    let index: Int
    let segment: Int
    let value: Double

    var id: String { "\(zone)-\(index)" }
    var series: String { "\(zone)-\(segment)" }
}

struct TrainerZoneRow: Identifiable {
    let zone: Int
    let paceTarget: String
    let pace: String
    let paceNote: String?
    let heartRateTarget: String
    let heartRate: String
    let heartRateNote: String?
    let hasPace: Bool
    let hasHeartRate: Bool

    var id: Int { zone }
}
