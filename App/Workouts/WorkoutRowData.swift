import Foundation
import TrainingCore

struct WorkoutRowData: Identifiable, Hashable {
    let activityId: Int64
    let title: String
    let dateText: String
    let distanceText: String?
    let durationText: String?
    let paceText: String?
    let hasPrescription: Bool
    var score: Int?
    let kilometers: Double?
    let zoneShares: [Double]
    let weekStart: Day

    var id: Int64 { activityId }
}

struct WorkoutWeek: Identifiable, Hashable {
    let start: Day
    let kilometers: Double
    let rows: [WorkoutRowData]

    var id: Day { start }
}
