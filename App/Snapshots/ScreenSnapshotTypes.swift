import Foundation
import Insights
import TrainingCore

enum ScreenSnapshotKind: String, CaseIterable, Sendable {
    case today
    case evolution
    case nextRace
    case raceList
}

struct ScreenSnapshotEnvelope<Payload: Codable>: Codable {
    let version: Int
    var build: String?
    let payload: Payload
}

struct ScreenSnapshotHeader: Decodable {
    let version: Int
    let build: String?
}

struct TodaySnapshot: Codable, Sendable {
    let today: Day
    let load: TodayLoad
}

struct EvolutionSnapshot: Codable, Sendable {
    let today: Day
    let period: MetricPeriod
    let overview: EvolutionOverview
    let cards: [MetricKind: MetricCardData]
}

struct NextRaceSnapshot: Codable, Sendable {
    let today: Day
    let load: NextRaceLoad
}

struct RaceListSnapshot: Codable, Sendable {
    let today: Day
    let load: RaceListLoad
}
