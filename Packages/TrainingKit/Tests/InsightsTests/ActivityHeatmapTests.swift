import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Insights

@Suite struct ActivityHeatmapTests {
    @Test func sumsKilometersPerDayWithinWindow() throws {
        let inside = daysAgo(3)
        let outside = daysAgo(7 * 6)
        let context = try makeContext([
            run(id: 1, daysAgo: 3, distance: 5_000),
            run(id: 2, daysAgo: 3, distance: 3_000),
            run(id: 3, daysAgo: 42, distance: 10_000),
            run(id: 4, daysAgo: 1, distance: 0),
        ])

        let map = try activityHeatmap(context: context, today: fixtureToday, weeks: 4)

        #expect(abs((map[inside] ?? 0) - 8) < 1e-9)
        #expect(map[outside] == nil)
        #expect(map[daysAgo(1)] == nil)
    }

    @Test func defaultWindowIsTwentySixWeeks() throws {
        let context = try makeContext([run(id: 1, daysAgo: 7 * 20, distance: 4_000), run(id: 2, daysAgo: 7 * 30, distance: 4_000)])
        let map = try activityHeatmap(context: context, today: fixtureToday)
        #expect(map.count == 1)
    }
}
