import Testing
import TrainingCore
@testable import trAIning

@Suite struct OverloadDetectorTests {
    private static let today = Day(iso: "2026-11-13")!

    private static func signals(recentResting: Int, recentHrv: Double) -> [DailySignal] {
        (0..<31).map { offset in
            let day = today.adding(days: -offset)
            return offset < 3
                ? DailySignal(day: day, restingHeartRate: recentResting, hrv: recentHrv)
                : DailySignal(day: day, restingHeartRate: 48, hrv: 62)
        }
    }

    @Test func alertsWhenRestingHighAndHrvLowForThreeDays() throws {
        let alert = try #require(OverloadDetector.alert(Self.signals(recentResting: 54, recentHrv: 55), today: Self.today, ratio: 1.1))

        #expect(alert.restingBase == 48 && alert.hrvBase == 62)
        #expect(alert.restingHigh && alert.hrvLow && !alert.loadHigh)
    }

    @Test func singleSignalNeedsHighLoad() {
        #expect(OverloadDetector.alert(Self.signals(recentResting: 54, recentHrv: 61), today: Self.today, ratio: 1.1) == nil)
        #expect(OverloadDetector.alert(Self.signals(recentResting: 54, recentHrv: 61), today: Self.today, ratio: 1.4) != nil)
        #expect(OverloadDetector.alert(Self.signals(recentResting: 49, recentHrv: 61), today: Self.today, ratio: 1.6) == nil)
    }
}
