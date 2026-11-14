import Foundation
import Insights
import Metrics
import Storage
import SwiftData
import TrainingCore

typealias RaceAnswer = (Int64, ModelContext) throws -> Void

enum RaceRoute: Hashable {
    case next(UUID)
    case completed(UUID)
}

enum StrategyState: Equatable, Sendable {
    case ok
    case infeasible
    case noGPX
    case noTarget
}

enum RaceDistanceOption: String, CaseIterable, Identifiable {
    case five, ten, half, full, other

    var id: String { rawValue }
}

enum AssessmentReference: Equatable, Sendable {
    case raceDayProjection
    case todayPrediction
}

enum ChecklistKind: Equatable, Sendable {
    case vo2max
    case longRun
    case thresholdPace
    case hrv
    case raceDayForm
}

enum ChecklistStatus: Equatable, Sendable {
    case ok
    case attention
    case missing
}

struct ChecklistItem: Identifiable, Equatable, Sendable {
    let kind: ChecklistKind
    let title: String
    let detail: String
    let status: ChecklistStatus

    var id: String { title }
}

struct RaceInfo: Equatable, Sendable {
    let id: UUID
    let name: String
    let day: Day
    let distance: Double
    let goalSeconds: Double?
    let priority: RacePriority
    let city: String?
    let startTime: String?
}

struct RaceRowData: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let dateText: String
    let distanceText: String
    let priority: String
    let detailText: String?
    let resultText: String?
    let isPR: Bool
    let isUpcoming: Bool
}

struct RaceSplit: Identifiable, Equatable, Sendable {
    let index: Int
    let distance: Double
    let pace: Double
    let planned: Double?

    var id: Int { index }
}

struct CompletedRaceSummary: Equatable, Sendable {
    let info: RaceInfo
    let resultSeconds: Double?
    let resultActivityId: Int64?
    let resultIsSuggestion: Bool
    let eveSeconds: Double?
    let isPR: Bool
    let splits: [RaceSplit]
    let lesson: String

    var goalSeconds: Double? { info.goalSeconds }
    var resultVsGoalText: String? { RacesText.signedClock(resultSeconds, minus: goalSeconds) }
    var resultVsEveText: String? { RacesText.signedClock(resultSeconds, minus: eveSeconds) }
    var eveNote: String? { eveSeconds == nil ? RacesConstants.noEvePrediction : nil }
}

struct GoalSummary: Equatable, Sendable {
    let goalSeconds: Double
    let goalPaceText: String
    let todaySeconds: Double?
    let raceDaySeconds: Double?
    let sentence: String?
}

struct EditorAssessment: Equatable, Sendable {
    let targetPaceText: String
    let reference: AssessmentReference
    let referenceSeconds: Double
    let level: GoalAssessment?
    let sentence: String

    var comparedText: String? {
        guard referenceSeconds > 0 else { return nil }
        return reference == .raceDayProjection ? RacesConstants.comparedRaceDay : RacesConstants.comparedToday
    }
}

struct NextRaceLoad: Sendable {
    let info: RaceInfo
    let outlook: RaceOutlook
    let target: StrategyTarget?
    let profile: [GPXPoint]?
    let manual: [Int: Double]
    let block: [BlockWeek]
    let checklist: [ChecklistItem]
    let blockReading: String
    let weeklyLongest: [Day: Double]
}

struct GPXPoint: Equatable, Sendable {
    let distance: Double
    let altitude: Double
}

struct RaceListLoad: Sendable {
    let candidates: [RaceCandidate]
    let upcoming: [RaceRowData]
    let completed: [RaceRowData]
    let summaries: [UUID: CompletedRaceSummary]
}

struct RaceResultCandidate: Sendable {
    let activityId: Int64
    let day: Day
    let distance: Double
    let seconds: Double
    let garminPR: Bool
}

struct PaceEditTarget: Identifiable {
    let plan: KmPlan

    var id: Int { plan.index }
}

struct ResultOption: Identifiable, Equatable, Sendable {
    let activityId: Int64
    let title: String
    let dateText: String
    let distanceText: String
    let durationText: String
    let isLinked: Bool

    var id: Int64 { activityId }
}
