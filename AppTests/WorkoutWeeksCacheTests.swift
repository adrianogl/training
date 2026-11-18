import Foundation
import Storage
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct WorkoutWeeksCacheTests {
    private func run(_ id: Int64, daysAgo: Double, score: Int? = nil) -> ActivityRecord {
        let record = ActivityRecord(activityId: id, typeKey: "running", name: "Corrida", start: Date(timeIntervalSince1970: 1_800_000_000 - daysAgo * 86_400), distance: 10_000, duration: 3_000)
        record.scoreValue = score
        return record
    }

    @Test func reusesTheGroupingUntilAWorkoutChanges() {
        let records = [run(1, daysAgo: 0, score: 80), run(2, daysAgo: 8)]
        let cache = WorkoutWeeksCache()
        let monday = cache.weeks(records: records, plannedKilometers: [:]).first?.start

        let first = cache.weeks(records: records, plannedKilometers: monday.map { [$0: 40] } ?? [:])
        #expect(first.count == 2)
        #expect(first.first?.plannedKilometers == 40)
        #expect(first.first?.rows.first?.score == 80)

        let signature = WorkoutWeeksCache.signature(records)
        records[0].scoreValue = 90
        #expect(WorkoutWeeksCache.signature(records) != signature)
        #expect(cache.weeks(records: records, plannedKilometers: [:]).first?.rows.first?.score == 90)
        #expect(cache.weeks(records: records, plannedKilometers: [:]).first?.plannedKilometers == nil)
    }
}
