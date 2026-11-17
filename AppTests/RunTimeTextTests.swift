import Testing
import TrainingCore
@testable import trAIning

@Suite struct RunTimeTextTests {
    @Test func minutesRoundOutward() {
        #expect(RunTimeText.range(RunTimeRange(fastest: 3_270, slowest: 3_435)) == "54–58 min")
    }

    @Test func hoursUseTheShortFormat() {
        #expect(RunTimeText.range(RunTimeRange(fastest: 6_300, slowest: 6_840)) == "1h45–1h54")
        #expect(RunTimeText.range(RunTimeRange(fastest: 3_480, slowest: 3_700)) == "58 min–1h02")
    }

    @Test func sameMinuteShowsOneValue() {
        #expect(RunTimeText.range(RunTimeRange(fastest: 2_400, slowest: 2_400)) == "40 min")
    }

    @Test func approximateGetsThePrefix() {
        #expect(RunTimeText.range(RunTimeRange(fastest: 2_880, slowest: 3_120, approximate: true)) == "≈ 48–52 min")
    }

    @Test func stepShowsClockEach() {
        #expect(RunTimeText.step(RunTimeRange(fastest: 100, slowest: 104), repeated: true) == "1:40–1:44 cada")
    }
}
