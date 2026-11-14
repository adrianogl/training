import GarminAPI
import Testing
import TrainingCore
@testable import trAIning

@Suite struct WatchFaceBuilderTests {
    private static let today = Day(iso: "2026-11-13")!

    private static func plan(_ day: Day, meters: Double?, steps: [PlannedStep] = []) -> PlannedWorkout {
        PlannedWorkout(id: Int64(day.iso.hashValue), day: day.iso, title: "Treino", estimatedSeconds: nil, estimatedMeters: meters, steps: steps)
    }

    @Test func weekPlannedKmSumsOnlyThisWeek() {
        let week = Self.today.weekStart
        let planned = [
            Self.plan(week, meters: 10_000),
            Self.plan(week.adding(days: 6), meters: 21_150),
            Self.plan(week.adding(days: 7), meters: 8_000),
            Self.plan(week.adding(days: 2), meters: nil),
        ]

        #expect(WatchFaceBuilder.weekPlannedKm(planned, today: Self.today) == 31.2)
        #expect(WatchFaceBuilder.weekPlannedKm([], today: Self.today) == nil)
    }

    @Test func shapeNormalizesWeightsAndKeepsZones() {
        let steps = [
            PlannedStep(kind: .warmup, seconds: 600),
            PlannedStep(kind: .active, seconds: 300, target: .zone(5)),
            PlannedStep(kind: .cooldown, seconds: 300),
        ]

        let shape = WatchFaceBuilder.shape(steps)

        #expect(shape?.map { $0[0] } == [50, 25, 25])
        #expect(shape?[1][1] == 5)
    }

    @Test func longShapeMergesPairsUpToLimit() {
        let repeats = PlannedStep(kind: .other, repeats: 20, children: [
            PlannedStep(kind: .active, seconds: 60, target: .zone(5)),
            PlannedStep(kind: .recovery, seconds: 60, target: .zone(1)),
        ])

        let shape = WatchFaceBuilder.shape([repeats])

        #expect((shape?.count ?? 0) <= WatchFaceConstants.shapeMaxSteps)
        #expect(shape?.allSatisfy { $0[1] == 5 } == true)
    }
}
