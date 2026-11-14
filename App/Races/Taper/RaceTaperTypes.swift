import TrainingCore

struct TaperWeek: Equatable, Sendable {
    let start: Day
    let doneKm: Double
    let targetKm: Double?
    let isRaceWeek: Bool
}

struct TaperHistory: Equatable, Sendable {
    let name: String
    let reduction: Double
    let deltaToGoal: Double
}

struct TaperPlan: Equatable, Sendable {
    let daysLeft: Int
    let baseKm: Double
    let weeks: [TaperWeek]
    let longestKm: Double
    let advice: String
    let best: TaperHistory?
}
