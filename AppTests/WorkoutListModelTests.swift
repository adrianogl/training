import Foundation
import GarminAPI
import Storage
import TrainingCore
import SwiftData
import Testing
import WorkoutAnalysis
@testable import trAIning

@MainActor
@Suite struct WorkoutListModelTests {
    private func run(_ id: Int64, day: Double, _ efforts: [(Double, Double)]) throws -> ActivityRecord {
        let record = ActivityRecord(
            activityId: id, typeKey: "running", name: "Rodagem",
            start: Date(timeIntervalSince1970: 1_793_000_000 + day * 86_400), distance: 12_000, duration: 3_600
        )
        record.bestEffortsData = try JSONEncoder().encode(efforts.map { RunEffort(meters: $0.0, seconds: $0.1, source: .segment) })
        return record
    }

    @Test func weekRowsCompareRecordsWithTheWholeHistory() throws {
        let old = try run(1, day: 0, [(1_000, 217), (5_000, 1_178), (10_000, 2_437)])
        let monday = try run(2, day: 30, [(1_000, 290), (5_000, 1_460), (10_000, 2_930)])
        let wednesday = try run(3, day: 32, [(1_000, 287), (5_000, 1_451), (10_000, 2_917)])
        let history = [old, monday, wednesday]

        let rows = WorkoutListModel.rows(records: [monday, wednesday], timeline: RecordTimelineCache().timeline(records: history))

        #expect(rows.compactMap(\.recordPill).isEmpty)
    }

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

        try #require(rows.count == 3)
        #expect(rows.map(\.activityId) == [3, 2, 1])
        #expect(rows[0].title == "Limiar 6 x 800 m")
        #expect(rows[0].paceText == "5:00 /km")
        #expect(rows[0].distanceText == "10,0 km")
        #expect(rows[0].durationText == "50:00")
        #expect(rows[1].isStrength)
        #expect(rows[1].paceText == nil)
        #expect(rows[1].distanceText == nil)
        #expect(rows[1].durationText == "40:00")
        #expect(rows[2].paceText == "5:50 /km")
        #expect(rows[2].durationText == "46:40")
        #expect(rows.map(\.hasPrescription) == [true, false, false])
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
        #expect(weeks[0].rows.map(\.activityId) == [2, 4, 1])
        #expect(weeks[0].kilometers == 18)
        #expect(weeks[0].runCount == 2)
        #expect(weeks[0].strengthCount == 1)
        #expect(weeks[1].rows.map(\.activityId) == [3])
        #expect(WorkoutListModel.weekLabel(weeks[0].start) == "9–15 nov")
        #expect(WorkoutListModel.weekSummary(weeks[0]) == "18,0 km · 2 corridas · 1 de força")
        #expect(weeks[0].rows[2].zoneShares == [0.2, 0.8, 0, 0, 0])
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
        #expect(rows.first { $0.activityId == 2 }?.score == nil)
    }
}

@Suite struct VisiblePlannedTests {
    private func plan(_ id: Int64, _ day: String, _ title: String) -> PlannedWorkout {
        PlannedWorkout(id: id, day: day, title: title, estimatedSeconds: nil, estimatedMeters: nil, steps: [])
    }

    private func row(_ id: Int64, _ day: String, names: [String]) -> WorkoutRowData {
        WorkoutRowData(
            activityId: id, title: names[0], names: names, dayIso: day, dateText: "", distanceText: nil,
            durationText: nil, paceText: nil, hasPrescription: false, score: nil, kilometers: nil,
            zoneShares: [], weekStart: Day(iso: day) ?? Day.today()
        )
    }

    @Test func hidesPlanMatchedByNameIgnoringCase() {
        let result = WorkoutListModel.visiblePlanned(
            planned: [plan(1, "2026-11-10", "Limiar 6 x 800 m")],
            rows: [row(10, "2026-11-10", names: ["limiar 6 x 800 M", "Corrida"]), row(11, "2026-11-10", names: ["Outra"])]
        )
        #expect(result.visible.isEmpty)
        #expect(result.fromPlanIds == [10])
    }

    @Test func hidesPlanWhenItIsTheOnlyRunOfTheDay() {
        let result = WorkoutListModel.visiblePlanned(
            planned: [plan(1, "2026-11-10", "Tiro")],
            rows: [row(10, "2026-11-10", names: ["Corrida livre"])]
        )
        #expect(result.visible.isEmpty)
        #expect(result.fromPlanIds == [10])
    }

    @Test func keepsPlanWhenSeveralRunsAndNoNameMatch() {
        let result = WorkoutListModel.visiblePlanned(
            planned: [plan(1, "2026-11-10", "Tiro")],
            rows: [row(10, "2026-11-10", names: ["A"]), row(11, "2026-11-10", names: ["B"])]
        )
        #expect(result.visible.map(\.id) == [1])
        #expect(result.fromPlanIds.isEmpty)
    }

    @Test func keepsPlanOnDayWithoutRunsAndSortsDescending() {
        let result = WorkoutListModel.visiblePlanned(
            planned: [plan(1, "2026-11-15", "A"), plan(2, "2026-11-17", "B"), plan(3, "2026-11-10", "C")],
            rows: [row(10, "2026-11-10", names: ["Z"])]
        )
        #expect(result.visible.map(\.id) == [2, 1])
        #expect(result.fromPlanIds == [10])
    }

    @Test func hidesPastPlansFromTheVisibleList() {
        let result = WorkoutListModel.visiblePlanned(
            planned: [plan(1, "2026-11-10", "A"), plan(2, "2026-11-16", "B")],
            rows: [],
            from: "2026-11-15"
        )
        #expect(result.visible.map(\.id) == [2])
    }
}

@MainActor
@Suite struct WorkoutKindFilterTests {
    private let monday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 7))!

    private func records(in container: ModelContainer) throws -> [ActivityRecord] {
        let context = container.mainContext
        context.insert(ActivityRecord(activityId: 1, typeKey: "running", name: "Rodagem leve", start: monday, distance: 6_000, duration: 2_100))
        context.insert(ActivityRecord(activityId: 2, typeKey: "running", name: "Corrida", start: monday.addingTimeInterval(86_400), distance: 9_000, duration: 2_700, workoutName: "Limiar 3 x 2 km"))
        context.insert(ActivityRecord(activityId: 3, typeKey: "running", name: "Longão", start: monday.addingTimeInterval(5 * 86_400), distance: 18_000, duration: 6_000))
        context.insert(ActivityRecord(activityId: 4, typeKey: "running", name: "Prova 10 km", start: monday.addingTimeInterval(-2 * 86_400), distance: 10_000, duration: 2_700))
        context.insert(ActivityRecord(activityId: 5, typeKey: "strength_training", name: "MMII", start: monday.addingTimeInterval(2 * 86_400), distance: 0, duration: 3_600))
        try context.save()
        return try context.fetch(FetchDescriptor<ActivityRecord>())
    }

    @Test func filtersRunsAndStrengthAndKeepsWeekTotals() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let records = try records(in: container)
        let weeks = WorkoutListModel.weeks(records: records)

        #expect(WorkoutListModel.filtered(weeks, by: .all) == weeks)

        let strength = WorkoutListModel.filtered(weeks, by: .strength)
        try #require(strength.count == 1)
        #expect(strength[0].rows.map(\.activityId) == [5])
        #expect(strength[0].rows[0].isStrength)
        #expect(strength[0].rows[0].distanceText == nil)
        #expect(strength[0].kilometers == 33)
        #expect(strength[0].runCount == 3)
        #expect(strength[0].strengthCount == 1)
        #expect(Set(WorkoutListModel.filtered(weeks, by: .run).flatMap(\.rows).map(\.activityId)) == [1, 2, 3, 4])
    }

    @Test func sumsPlannedKilometersPerWeekOverCache() {
        let plans = [
            PlannedWorkout(id: 1, day: "2026-11-10", title: "Limiar", estimatedSeconds: nil, estimatedMeters: 9_000, steps: []),
            PlannedWorkout(id: 2, day: "2026-11-14", title: "Longão", estimatedSeconds: nil, estimatedMeters: 18_500, steps: []),
            PlannedWorkout(id: 3, day: "2026-11-12", title: "Força", estimatedSeconds: 2_400, estimatedMeters: nil, steps: []),
        ]
        let weeks = WorkoutListModel.plannedKilometers(
            planned: plans,
            cached: ["2026-11-09": 20, "2026-11-02": 40.5, "2026-10-26": 0]
        )

        #expect(weeks == [Day(iso: "2026-11-09")!: 27.5, Day(iso: "2026-11-02")!: 40.5])
    }

    @Test func weekSummaryShowsDoneOverPlanned() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let records = try records(in: container)
        let weeks = WorkoutListModel.weeks(records: records, plannedKilometers: [Day(iso: "2026-11-09")!: 40])

        try #require(weeks.count == 2)
        #expect(WorkoutListModel.weekSummary(weeks[0]) == "33,0 de 40,0 km · 3 corridas · 1 de força")
        #expect(weeks[0].plannedProgress == 33.0 / 40)
        #expect(weeks[1].plannedProgress == nil)
        #expect(WorkoutListModel.weekSummary(weeks[1]) == "10,0 km · 1 corrida")
        #expect(WorkoutListModel.weekSummary(WorkoutWeek(start: weeks[0].start, kilometers: 0, rows: [], runCount: 0, strengthCount: 2)) == "2 de força")
    }
}
