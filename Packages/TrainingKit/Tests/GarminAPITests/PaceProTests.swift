import Foundation
import Testing
@testable import GarminAPI

private let summariesJSON = """
[{"paceBandPk":8889524,"name":"Live! Run XP","courseId":514884211,"splitType":"DISTANCE_KILOMETER","totalDistance":10004.84,"goalTime":2400,"createdDate":"2026-09-14T20:37:40.0"},
 {"paceBandPk":11,"name":"Meia","totalDistance":21097,"goalTime":5400,"createdDate":"2026-01-01T10:00:00.0"},
 {"paceBandPk":12,"name":"10 antigo","totalDistance":10000,"goalTime":2460,"createdDate":"2025-05-01T10:00:00.0"}]
"""

private let planJSON = """
{"paceBandPk":8889524,"paceBandSummary":{"paceBandPk":8889524,"name":"Live! Run XP","totalDistance":10004.84,"goalTime":2400,"createdDate":"2026-09-14T20:37:40.0"},
 "paceBandSplits":[
  {"cumulativeDistanceFromStart":2000.0,"cumulativeTimeFromStart":477.300},
  {"cumulativeDistanceFromStart":1000.0,"cumulativeTimeFromStart":237.259},
  {"cumulativeDistanceFromStart":2027.8,"cumulativeTimeFromStart":484.0}
 ]}
"""

@Suite struct PaceProTests {
    @Test func picksNewestPlanWithRaceDistance() throws {
        let summaries = try PacePro.parseSummaries(Data(summariesJSON.utf8))
        #expect(PacePro.match(summaries, distance: 10_000)?.id == 8889524)
        #expect(PacePro.match(summaries, distance: 21_100)?.id == 11)
        #expect(PacePro.match(summaries, distance: 42_195) == nil)
    }

    @Test func readsKilometerSecondsFromCumulativeSplits() throws {
        let plan = try #require(try PacePro.parsePlan(Data(planJSON.utf8)))
        #expect(plan.summary.goalSeconds == 2400)
        #expect(plan.splits.map(\.distance) == [1000, 2000, 2027.8])
        let seconds = plan.kilometerSeconds
        #expect(seconds.count == 2)
        #expect(abs(seconds[0] - 237.259) < 0.001)
        #expect(abs(seconds[1] - 240.041) < 0.001)
    }
}
