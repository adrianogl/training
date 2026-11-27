import Foundation
import TrainingCore

public struct TrainerSwapWarning: Sendable, Equatable {
    public var title: String
    public var text: String

    public init(title: String, text: String) {
        self.title = title
        self.text = text
    }
}

struct TrainerSwapConflict: Equatable {
    var quality: TrainerWorkout
    var long: TrainerWorkout
}
