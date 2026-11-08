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

        let rows = WorkoutListModel.rows(filter: .run, records: records)

        try #require(rows.count == 2)
        #expect(rows.map(\.activityId) == [3, 1])
        #expect(rows[0].title == "Limiar 6 x 800 m")
        #expect(rows[0].paceText == "5:00 /km")
        #expect(rows[0].distanceText == "10,0 km")
        #expect(rows[0].durationText == "50:00")
        #expect(rows[1].paceText == "5:50 /km")
        #expect(rows[1].durationText == "46:40")
        #expect(rows.map(\.hasPrescription) == [true, false])
        #expect(WorkoutListModel.rows(filter: .strength, records: records).map(\.activityId) == [2])
        #expect(WorkoutListModel.rows(filter: .all, records: records).count == 3)
    }
}
