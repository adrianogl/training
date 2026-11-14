import Foundation
import Testing
import TrainingCore
@testable import trAIning

@Suite struct EvolutionExtrasTests {
    private typealias F = WorkoutDetailFixtures

    @Test func zoneWeeksSumSecondsPerWeekAndEasyShare() {
        let today = Day.today(now: F.base)
        let first = F.run(id: 1, daysAgo: 0, meters: 8_000)
        first.zoneSeconds = [600, 1_800, 300, 200, 100]
        let second = F.run(id: 2, daysAgo: 70, meters: 8_000)
        second.zoneSeconds = [1_000, 1_000, 0, 0, 0]

        let weeks = EvolutionExtras.zoneWeeks([first, second], today: today)

        #expect(weeks.count == EvolutionExtrasConstants.zoneWeeks)
        #expect(weeks.last?.seconds == [600, 1_800, 300, 200, 100])
        #expect(EvolutionExtras.easyShare(weeks) == 0.8)
    }

    @Test func recordsUseGarminSplitsAndScaledRaceDistances() {
        let tenK = F.run(id: 1, daysAgo: 10, meters: 10_100)
        tenK.fastestSplit_1000 = 211
        let other = F.run(id: 2, daysAgo: 20, meters: 5_000)
        other.fastestSplit_5000 = 1_164
        other.fastestSplit_1000 = 220

        let records = EvolutionExtras.records([tenK, other])

        #expect(records.map(\.label) == ["1 km", "5 km", "10 km"])
        #expect(records[0].seconds == 211)
        #expect(records[1].seconds == 1_164)
        #expect(abs(records[2].seconds - 10_100 * 0.33 * 10_000 / 10_100) < 0.01)
    }
}
