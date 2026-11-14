struct WorkoutGoalEntry: Equatable, Identifiable {
    let id: String
    let title: String
    let status: String
    let good: Bool
    let lines: [String]
}
