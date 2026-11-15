import Foundation
import Insights
import TrainingCore

enum TrainerRoute: Hashable, Codable {
    case day(String)
    case changes
    case strength
}

enum TrainerTargetMode: String, CaseIterable, Identifiable {
    case race
    case text
    case paceDistance

    var id: String { rawValue }
}

enum TrainerTone: Equatable {
    case good
    case attention
    case bad
    case dim
}

struct TrainerStatusLabel: Equatable {
    let text: String
    let tone: TrainerTone
}

struct TrainerDayRow: Identifiable, Equatable {
    let workout: TrainerWorkout
    let status: TrainerDayStatus
    let run: TrainerRun?
    let isChanged: Bool
    var strength: [TrainerStrengthLine] = []

    var id: String { workout.id }
}

struct TrainerStrengthLine: Identifiable, Equatable {
    let id: UUID
    let name: String
    let isDone: Bool
}

struct TrainerStrengthRow: Identifiable, Equatable {
    let session: TrainerStrengthSession
    let caption: String

    var id: UUID { session.id }
}

struct TrainerWeekGroup: Identifiable, Equatable {
    let start: Day
    let title: String
    let caption: String
    let rows: [TrainerDayRow]

    var id: String { start.iso }
}

struct TrainerStepRow: Identifiable, Equatable {
    let id: Int
    let kind: TrainerStepKind
    let title: String
    let detail: String
    var isHeader = false
    var isNested = false
}

struct TrainerShapeBar: Identifiable, Equatable {
    let id: Int
    let kind: TrainerStepKind
    let meters: Double
    var isRest = false
}

struct TrainerWeekCell: Identifiable, Equatable {
    let id: Int
    let title: String
    let kilometers: String
    let detail: String
    let phase: TrainerPhase?
    let isCurrent: Bool
    let isPast: Bool
    let isChanged: Bool
    let isRace: Bool
    var start: Day?
    var isLight = false
}

struct TrainerRaceOption: Identifiable, Equatable {
    let id: UUID
    let name: String
    let day: Day
    let distance: Double
    let goalSeconds: Double?
}

struct TrainerRequestShortcut: Identifiable, Equatable {
    let category: TrainerRequestCategory
    let title: String
    let prefix: String

    var id: TrainerRequestCategory { category }
}

struct TrainerChangeStyle: Equatable {
    let symbol: String
    let tone: TrainerChangeTone
}

enum TrainerChangeTone: Equatable {
    case race
    case attention
    case good
    case info
    case rest
}

struct TrainerStrengthDraft: Identifiable {
    let session: TrainerStrengthSession
    let isNew: Bool

    var id: UUID { session.id }
}

enum TrainerStrengthResult {
    case save(TrainerStrengthSession)
    case remove(UUID)
}

struct TrainerBestTime: Equatable {
    let hour: Int
    let temperature: Double
    let heat: TrainerHeat
    let laterHotHour: Int?
}
