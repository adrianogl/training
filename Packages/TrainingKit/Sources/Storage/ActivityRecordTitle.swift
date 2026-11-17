import TrainingCore

public extension ActivityRecord {
    var displayTitle: String {
        workoutName.map(WorkoutTitle.clean) ?? name
    }
}
