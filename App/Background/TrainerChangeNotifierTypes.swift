import Foundation
import Insights

enum TrainerChangeWatch: Equatable {
    case none, current, pending
}

struct TrainerChangePending: Codable, Equatable {
    let before: TrainerWorkout?
    let at: Date?
}
