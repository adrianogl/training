import Foundation
import GarminAPI

struct PaceProCache: Codable, Sendable {
    var summaries: [PaceProSummary] = []
    var plans: [PaceProPlan] = []
}

struct RacePlanRow: Identifiable, Equatable {
    var id: Int { index }
    let index: Int
    let planned: Double
    let done: Double
    let cumulative: Double
    var hasWater = false

    var delta: Double { done - planned }
}

struct RacePlanComparison: Equatable {
    let sourceName: String?
    let planSeconds: Double?
    let rows: [RacePlanRow]
    let verdict: String
}
