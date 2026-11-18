import Testing
@testable import Insights

@Suite struct TrainerRecentRaceTests {
    @Test func fiveKInTwentyFiveMinutesGivesOrderedPaces() throws {
        let paces = TrainerEngine.pacesFromRecentRace(meters: 5000, seconds: 25 * 60)
        let easy = try #require(paces[.easy])
        let threshold = try #require(paces[.threshold])
        let vo2 = try #require(paces[.vo2max])
        #expect(vo2 == 295)
        #expect(threshold > vo2)
        #expect(easy > threshold)
        #expect(abs(easy - 381) <= 1)
    }

    @Test func emptyInputGivesNoOverrides() {
        #expect(TrainerEngine.pacesFromRecentRace(meters: 0, seconds: 100).isEmpty)
    }
}
