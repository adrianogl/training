import TrainingCore

struct ReportRun: Equatable, Sendable {
    let title: String
    let kilometers: Double
    let score: Int?
}

struct WeeklyReport: Equatable {
    let start: Day
    let isCurrentWeek: Bool
    let doneKm: Double
    let runs: Int
    let plannedKm: Double?
    let adherence: Double?
    let best: ReportRun?
    let headline: String
    let text: String
    let notification: String
}
