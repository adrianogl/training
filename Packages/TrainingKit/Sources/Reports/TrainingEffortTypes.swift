import Metrics
import TrainingCore
import WorkoutAnalysis

struct TrainingEffortRule {
    var runKind: RunKind
    var effortKind: EffortKind
    var minimumMeters: Double
    var distance: Double
    var paceOffset: Double
}

public struct TrainingSession: Sendable, Equatable {
    public var day: Day
    public var work: WorkPace

    public init(day: Day, work: WorkPace) {
        self.day = day
        self.work = work
    }
}
