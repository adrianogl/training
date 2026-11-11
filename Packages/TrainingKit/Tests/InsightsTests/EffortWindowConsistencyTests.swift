import Testing
@testable import Insights
@testable import Metrics

@Suite struct EffortWindowConsistencyTests {
    @Test func insightsAndRaceUseTheSameEffortWindow() {
        #expect(Double(InsightsConstants.effortWindowDays) == RaceConstants.effortWindowDays)
    }
}
