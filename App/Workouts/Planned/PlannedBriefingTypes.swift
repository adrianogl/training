import Foundation
import GarminAPI
import TrainingCore

enum PlannedKind: Equatable {
    case long, intervals, tempo, easy
}

enum BriefingTone: Equatable {
    case good, info, warn, bad
}

struct SimilarRun: Equatable {
    let day: Day
    let kilometers: Double
    let paceSecondsPerKm: Double
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let aerobicEffect: Double?
    let load: Double?
    let fadeSecondsPerKm: Double?
}

struct HourlyWeather: Equatable {
    let hour: Int
    let temperature: Double
    let dewPoint: Double?
}

struct CourseSuggestion: Equatable {
    let name: String
    let lapKilometers: Double
    let laps: Int
    let elevationGain: Double?
    let profile: [Double]
}

struct CompletedCheck: Equatable {
    let kilometers: Double
    let paceSecondsPerKm: Double?
    let averageHeartRate: Double?
    let fadeSecondsPerKm: Double?
}

struct PlannedRaceContext: Equatable {
    let name: String
    let days: Int
    let longestKilometers: Double
    let longTargetKilometers: Double
}

struct BriefingInput {
    let plan: PlannedWorkout
    let today: Day
    let similar: [SimilarRun]
    let readiness: Int?
    let weekDoneKm: Double
    let weekPlannedKm: Double
    let weekGoalKm: Double?
    let daysSinceHard: Int?
    let race: PlannedRaceContext?
    let weather: [HourlyWeather]
    let course: CourseSuggestion?
    let completed: CompletedCheck?
}

struct BriefingStat: Equatable {
    let value: String
    let label: String
}

struct BriefingTag: Equatable {
    let text: String
    let tone: BriefingTone
}

struct BriefingPhase: Equatable {
    let when: String
    let length: String?
    let title: String
    let detail: String
}

struct BriefingRep: Equatable {
    let label: String
    let pace: String
    let heartRate: String?
    let note: String
}

struct BriefingItem: Equatable {
    let title: String
    let detail: String
    let tone: BriefingTone
}

struct BriefingComparison: Equatable {
    let label: String
    let planned: String
    let done: String
    let ok: Bool
}

struct PlannedBriefing: Equatable {
    let kind: PlannedKind
    let stats: [BriefingStat]
    let summary: String
    let tags: [BriefingTag]
    let phases: [BriefingPhase]
    let reps: [BriefingRep]
    let repsNote: String?
    let expectations: [BriefingStat]
    let expectationNote: String?
    let attention: [BriefingItem]
    let planB: [BriefingItem]
    let previous: [SimilarRun]
    let previousNote: String?
    let carry: [String]
    let raceNote: String?
    let bestHours: [HourlyWeather]
    let bestHoursNote: String?
    let course: CourseSuggestion?
    let comparison: [BriefingComparison]
    let comparisonNote: String?
    let watchTip: String?
}
