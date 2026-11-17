import Insights
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

    @Test func trainingStatusKeepsOnlyKnownKeys() {
        #expect(WatchFaceBuilder.trainingStatusKey("MAINTAINING_2") == "MAINTAINING")
        #expect(WatchFaceBuilder.trainingStatusKey("PRODUCTIVE_10") == "PRODUCTIVE")
        #expect(WatchFaceBuilder.trainingStatusKey("NO_STATUS_1") == nil)
        #expect(WatchFaceBuilder.trainingStatusKey(nil) == nil)
    }

    @Test func nextWeekShowsPhaseOrLightWeekWithKilometers() {
        let start = Self.today.weekStart
        var plan = TrainerStoreTests.plan()
        plan.weeks = [
            TrainerWeek(index: 1, start: start, phase: .base, isRecovery: false, plannedMeters: 52_000, longMeters: 16_000, thresholdFocus: "", vo2Focus: ""),
            TrainerWeek(index: 2, start: start.adding(days: 7), phase: .build, isRecovery: false, plannedMeters: 58_400, longMeters: 18_000, thresholdFocus: "", vo2Focus: ""),
        ]
        var light = plan
        light.weeks[1].isRecovery = true

        #expect(WatchFaceBuilder.nextWeekText(plan: plan, today: Self.today) == "Construção · 58 km")
        #expect(WatchFaceBuilder.nextWeekText(plan: light, today: Self.today) == "Semana leve · 58 km")
        #expect(WatchFaceBuilder.nextWeekText(plan: plan, today: start.adding(days: 7)) == nil)
        #expect(WatchFaceBuilder.nextWeekText(plan: nil, today: Self.today) == nil)
    }
}
