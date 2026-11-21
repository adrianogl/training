import Foundation
import Testing
@testable import trAIning

@Suite struct IntroPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_795_000_000)

    @Test func showsOnFirstLaunch() {
        #expect(IntroPolicy.shows(lastActive: nil, now: now))
    }

    @Test func skipsWhenUsedInTheLastSixHours() {
        #expect(!IntroPolicy.shows(lastActive: now.addingTimeInterval(-5 * 3_600), now: now))
        #expect(!IntroPolicy.shows(lastActive: now.addingTimeInterval(-60), now: now))
    }

    @Test func showsAfterSixHoursAway() {
        #expect(IntroPolicy.shows(lastActive: now.addingTimeInterval(-6 * 3_600 - 1), now: now))
    }

    @Test func showsWhenClockWentBack() {
        #expect(IntroPolicy.shows(lastActive: now.addingTimeInterval(3_600), now: now))
    }

    @Test func remembersLastActive() {
        let defaults = UserDefaults(suiteName: "intro-" + UUID().uuidString)!
        #expect(IntroPolicy.shows(defaults: defaults, now: now))
        IntroPolicy.markActive(defaults: defaults, now: now)
        #expect(!IntroPolicy.shows(defaults: defaults, now: now.addingTimeInterval(3_600)))
    }
}
