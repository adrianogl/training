import TrainingCore

struct ReportRun: Equatable, Sendable, Codable {
    var title: String
    var kilometers: Double
    var score: Int?
    var day: String? = nil
    var kind: SessionKind? = nil
    var paceSeconds: Double? = nil
}

enum WeeklyDayState: Equatable {
    case done
    case partial
    case missed
    case pending
    case off
}

struct WeeklyDay: Equatable, Identifiable {
    let day: Day
    let weekday: String
    let plannedKm: Double?
    let doneKm: Double?
    let kind: SessionKind?
    let label: String?
    let state: WeeklyDayState

    var id: Day { day }
}

struct ReportBest: Equatable {
    let title: String
    let detail: String
    let score: Int
}

struct ReportRace: Equatable {
    var name: String
    var days: Int
    var day: Day? = nil
    var prediction: String? = nil
}

struct ReportCount: Equatable {
    let done: Int
    let planned: Int
}

struct ReportLong: Equatable {
    let doneKm: Double
    let plannedKm: Double
}

struct WeeklyReport: Equatable {
    let start: Day
    let isCurrentWeek: Bool
    let doneKm: Double
    let runs: Int
    let plannedKm: Double?
    let adherence: Double?
    let percent: Int?
    let missingKm: Double?
    let isComplete: Bool
    let days: [WeeklyDay]
    let runCount: ReportCount?
    let quality: ReportCount?
    let long: ReportLong?
    let best: ReportRun?
    let bestCard: ReportBest?
    let race: ReportRace?
    let note: String
    let headline: String
    let text: String
    let notification: String
}

struct ShownWeek: Equatable {
    let start: Day
    let isCurrent: Bool
    let isClosed: Bool
}
