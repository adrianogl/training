import Foundation

struct WorkoutRowData: Identifiable, Hashable {
    let activityId: Int64
    let title: String
    let dateText: String
    let distanceText: String?
    let durationText: String?
    let paceText: String?
    let hasPrescription: Bool
    var score: Int?

    var id: Int64 { activityId }
}
