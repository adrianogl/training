import Foundation
import Insights
import TrainingCore

enum StrengthPlanValidityMode: String, CaseIterable, Hashable {
    case untilRace, weeks, untilDate
}

struct StrengthPlanDraft: Equatable {
    var id: UUID
    var objective: StrengthObjective
    var sessions: [TrainerStrengthSession]
    var start: Day
    var mode: StrengthPlanValidityMode
    var weeks: Int
    var untilDate: Day
    var race: TrainerRaceOption?
    var builder: StrengthPlanBuilder
    var createdAt: Date
    var endedNotifiedAt: Date?
    var startEdited: Bool
    var isNew: Bool
}

struct StrengthPlanCardSummary: Equatable {
    let label: String
    let builder: String
    let title: String
    let period: String
    let share: Double
    let progress: String
}

struct StrengthPlanEndedSummary: Equatable {
    let title: String
    let body: String
}

struct StrengthMFITSummary: Equatable {
    let title: String
    let subtitle: String
}

enum StrengthPlanFormRequest: Identifiable, Equatable {
    case new(StrengthObjective)
    case edit

    var id: String {
        switch self {
        case .new(let objective): "new-\(objective.rawValue)"
        case .edit: "edit"
        }
    }
}

struct StrengthDayCardModel: Equatable {
    let source: TrainerStrengthSource
    let isClaude: Bool
    let minutes: Int?
    let title: String
    let subtitle: String?
    var note: String?
    let isDone: Bool
    let showsLink: Bool
}
