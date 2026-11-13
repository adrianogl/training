import Foundation
import Storage
import SwiftData
import Testing
@testable import trAIning

@MainActor
@Suite struct WorkoutListModelTests {
    @Test func filtersAndFormatsRows() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let base = Date(timeIntervalSince1970: 1_793_000_000)
        context.insert(ActivityRecord(
            activityId: 1, typeKey: "running", name: "Corrida livre",
            start: base.addingTimeInterval(-86_400), distance: 8_000, duration: 2_800
        ))
        context.insert(ActivityRecord(
            activityId: 2, typeKey: "strength_training", name: "Força",
            start: base.addingTimeInterval(-3_600), duration: 2_400
        ))
        context.insert(ActivityRecord(
            activityId: 3, typeKey: "running", name: "Corrida",
            start: base, distance: 10_000, duration: 3_240, movingDuration: 3_000, workoutName: "Limiar 6 x 800 m"
        ))
        try context.save()
        let records = try context.fetch(FetchDescriptor<ActivityRecord>())

        let rows = WorkoutListModel.rows(records: records)

        try #require(rows.count == 2)
        #expect(rows.map(\.activityId) == [3, 1])
        #expect(rows[0].title == "Limiar 6 x 800 m")
        #expect(rows[0].paceText == "5:00 /km")
        #expect(rows[0].distanceText == "10,0 km")
        #expect(rows[0].durationText == "50:00")
        #expect(rows[1].paceText == "5:50 /km")
        #expect(rows[1].durationText == "46:40")
        #expect(rows.map(\.hasPrescription) == [true, false])
        #expect(rows[0].kilometers == 10)
    }

    @Test func groupsRunsByWeekWithTotals() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let monday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 7))!
        context.insert(ActivityRecord(activityId: 1, typeKey: "running", name: "A", start: monday, distance: 8_000, duration: 2_800, zoneSeconds: [60, 240, 0, 0, 0]))
        context.insert(ActivityRecord(activityId: 2, typeKey: "running", name: "B", start: monday.addingTimeInterval(2 * 86_400), distance: 10_000, duration: 3_000))
        context.insert(ActivityRecord(activityId: 3, typeKey: "running", name: "C", start: monday.addingTimeInterval(-3 * 86_400), distance: 12_000, duration: 4_000))
        context.insert(ActivityRecord(activityId: 4, typeKey: "strength_training", name: "Força", start: monday.addingTimeInterval(86_400), duration: 2_400))
        try context.save()

        let weeks = WorkoutListModel.weeks(records: try context.fetch(FetchDescriptor<ActivityRecord>()))

        try #require(weeks.count == 2)
        #expect(weeks[0].rows.map(\.activityId) == [2, 1])
        #expect(weeks[0].kilometers == 18)
        #expect(weeks[1].rows.map(\.activityId) == [3])
        #expect(WorkoutListModel.weekLabel(weeks[0].start) == "9–15 nov")
        #expect(WorkoutListModel.weekSummary(weeks[0]) == "18,0 km · 2 corridas")
        #expect(weeks[0].rows[1].zoneShares == [0.2, 0.8, 0, 0, 0])
    }

    @Test func listShowsScoreOnlyForRuns() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let run = WorkoutDetailFixtures.run(id: 1, meters: 5_900, workoutName: "Tiros 3 x 1 km", structure: WorkoutDetailFixtures.intervalStructure())
        context.insert(run)
        context.insert(ActivityRecord(
            activityId: 2, typeKey: "strength_training", name: "Força",
            start: WorkoutDetailFixtures.base, duration: 2_400
        ))
        try context.save()

        await ScoreStore.refresh(container: container, ids: nil)
        let records = try ModelContext(container).fetch(FetchDescriptor<ActivityRecord>())
        let rows = WorkoutListModel.rows(records: records)

        #expect(rows.first { $0.activityId == 1 }?.score != nil)
        #expect(!rows.contains { $0.activityId == 2 })
    }
}
