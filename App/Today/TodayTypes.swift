import Foundation
import Insights
import Metrics
import TrainingCore

enum TodayRoute: Hashable {
    case readiness
    case workout(Int64)
}

struct LastRunSummary: Equatable, Sendable {
    let activityId: Int64
    let title: String
    let dateText: String
    let kilometers: Double?
    let paceSeconds: Double?
    let averageHeartRate: Int?
    let evolution: String?
    let evolutionOnDevice: Bool
    let notice: String?
    let score: Int?
}

struct ReadinessDay: Equatable, Sendable {
    var sleepSeconds: Int?
    var stress: Int?
}

struct TodayLoad: Sendable {
    let summary: TodaySummary
    let readinessDay: ReadinessDay
    let lastRun: LastRunSummary?
    let raceName: String?
    let weekRuns: [Day: [WeekRun]]
    let recoveryRun: RecoveryRun?
}

struct WeekRun: Identifiable, Equatable, Sendable {
    let activityId: Int64
    let title: String
    let kilometers: Double
    let score: Int?
    let zoneShares: [Double]

    var id: Int64 { activityId }
}

enum ReadinessGroup {
    case up
    case down
    case baseline
    case missing
}

struct ReadinessFactorRowData: Identifiable, Equatable {
    let component: ReadinessComponent
    let name: String
    let detail: String
    let pointsText: String?
    let points: Double?
    let group: ReadinessGroup

    var id: ReadinessComponent { component }
}

struct ChartLine: Identifiable {
    let name: String
    let colorKey: ChartColorKey
    let dashed: Bool
    let points: [ChartPoint]

    var id: String { name }
}

enum ChartColorKey {
    case fitness
    case form
    case prediction
    case projection
}

struct ChartPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct ChartBandPoint: Identifiable {
    let date: Date
    let low: Double
    let high: Double

    var id: Date { date }
}

extension TodaySummary {
    static var empty: TodaySummary {
        TodaySummary(
            readiness: nil,
            verdict: nil,
            supporting: ReadinessSupport(hrvVsBaseline: nil, sleepScore: nil, acuteChronic: nil, stress: nil),
            fitness: FitnessOutlook(history: [], projection: [], peakFitness: nil, raceDayForm: nil),
            race: RaceOutlook(
                distance: 0, label: "", today: nil, raceDay: nil, yearAgo: nil, series: [], projection: [],
                goalSeconds: nil, goalCrossing: .noGoal, assessment: nil
            ),
            raceCountdownDays: nil,
            racePriority: nil,
            week: WeekVolume(perDay: [:], total: 0, lastWeek: 0, average4Weeks: 0),
            predictions: [],
            lastRunId: nil
        )
    }
}
