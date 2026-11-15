import Foundation
import TrainingCore

struct LastRunSplit: Equatable, Sendable, Codable, Identifiable {
    let km: Int
    let paceSeconds: Double
    let heartRate: Double?

    var id: Int { km }
}

struct LastRunSimilar: Equatable, Sendable, Codable, Identifiable {
    let activityId: Int64
    let dateText: String
    let kilometers: Double
    let elevationGain: Double?
    let paceSeconds: Double?
    let averageHeartRate: Int?

    var id: Int64 { activityId }
}

struct LastRunChartPoint: Equatable, Identifiable {
    let km: Int
    let value: Double

    var id: Int { km }
}

struct LastRunChartData: Equatable {
    let pace: [LastRunChartPoint]
    let heartRate: [LastRunChartPoint]
}

struct LastRunReference: Equatable {
    let dateText: String
    let paceSeconds: Double?
    let averageHeartRate: Int?
}
