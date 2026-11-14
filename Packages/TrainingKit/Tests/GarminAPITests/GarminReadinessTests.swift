import Foundation
import Testing
import TrainingCore
@testable import GarminAPI

private let readinessJSON = """
[
 {"calendarDate":"2026-11-14","timestamp":"2026-11-14T03:49:38.0","score":50,"level":"MODERATE"},
 {"calendarDate":"2026-11-14","timestamp":"2026-11-14T09:10:02.0","score":46,"level":"MODERATE"},
 {"calendarDate":"2026-11-13","timestamp":"2026-11-13T07:00:00.0","score":80,"level":"HIGH"}
]
"""

@Suite struct GarminReadinessTests {
    private let day = Day(year: 2026, month: 11, day: 14)

    @Test func picksTheLatestScoreOfTheDay() throws {
        let entries = try GarminReadiness.entries(Data(readinessJSON.utf8))

        #expect(GarminReadiness.latest(entries, day: day) == GarminReadinessScore(day: "2026-11-14", score: 46))
    }

    @Test func acceptsSingleObjectAndEmptyBody() throws {
        let single = try GarminReadiness.entries(Data(#"{"calendarDate":"2026-11-14","score":50}"#.utf8))

        #expect(GarminReadiness.latest(single, day: day)?.score == 50)
        #expect(try GarminReadiness.entries(Data()).isEmpty)
        #expect(GarminReadiness.latest(try GarminReadiness.entries(Data("[]".utf8)), day: day) == nil)
    }
}
