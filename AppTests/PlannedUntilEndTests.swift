import Foundation
import GarminAPI
import Testing
import TrainingCore
@testable import trAIning

@Suite struct PlannedUntilEndTests {
    private let today = Day(iso: "2026-11-21")!

    @Test func endIsTheLatestOfPrescriptionAndPlan() {
        #expect(WorkoutListModel.plannedEnd(today: today, mfitEnd: "2027-01-15", planEnd: Day(iso: "2026-12-20")) == Day(iso: "2027-01-15"))
        #expect(WorkoutListModel.plannedEnd(today: today, mfitEnd: nil, planEnd: Day(iso: "2026-12-20")) == Day(iso: "2026-12-20"))
        #expect(WorkoutListModel.plannedEnd(today: today, mfitEnd: nil, planEnd: nil) == today.adding(days: WorkoutConstants.plannedDays))
        #expect(WorkoutListModel.plannedEnd(today: today, mfitEnd: "2026-11-22", planEnd: nil) == today.adding(days: WorkoutConstants.plannedDays))
        #expect(WorkoutListModel.plannedEnd(today: today, mfitEnd: "2028-01-01", planEnd: nil) == today.adding(days: WorkoutConstants.plannedMaxDays))
    }

    @Test func plannedItemsGroupByWeekFromTheFarthest() {
        let items: [WorkoutPlannedItem] = [
            .strength(StrengthWorkout(id: 1, day: "2026-12-08", title: "A", blocks: [])),
            .strength(StrengthWorkout(id: 2, day: "2026-11-24", title: "B", blocks: [])),
            .strength(StrengthWorkout(id: 3, day: "2026-11-26", title: "C", blocks: [])),
        ]
        let groups = WorkoutListModel.plannedGroups(items)
        #expect(groups.map(\.start.iso) == ["2026-12-07", "2026-11-23"])
        #expect(groups.last?.items.map(\.day) == ["2026-11-26", "2026-11-24"])
    }
}
