import Foundation
import SwiftUI
import GarminAPI
import Testing
import TrainingCore
@testable import trAIning

@Suite struct WorkoutCalendarTests {
    private func row(_ id: Int64, _ day: String, km: Double?, strength: Bool = false) -> WorkoutRowData {
        var data = WorkoutRowData(
            activityId: id, title: "x", names: ["x"], dayIso: day, dateText: "", distanceText: nil, durationText: nil, paceText: nil,
            hasPrescription: false, score: nil, kilometers: km, zoneShares: [], weekStart: Day(iso: day)!.weekStart
        )
        data.isStrength = strength
        return data
    }

    @Test func gridStartsOnMondayAndCoversTheWholeMonth() {
        let grid = WorkoutCalendarModel.grid(month: Day(year: 2026, month: 11, day: 1))
        #expect(grid.count % 7 == 0)
        #expect(grid.first == Day(iso: "2026-10-26"))
        #expect(grid.contains(Day(iso: "2026-11-30")!))
        #expect(grid.last == Day(iso: "2026-12-06"))
    }

    @Test func daysMarkRunsStrengthPlannedAndMFIT() {
        let plannedRun = PlannedWorkout(id: 5, day: "2026-11-22", title: "Prova", estimatedSeconds: nil, estimatedMeters: 10_000, steps: [])
        let mfit = StrengthWorkout(id: 7, day: "2026-11-24", title: "Treino A", blocks: [])
        let trainer = StrengthWorkout(id: 8, day: "2026-11-21", title: "Mobilidade", blocks: [])
        let days = WorkoutCalendarModel.days(
            rows: [row(1, "2026-11-20", km: 8), row(2, "2026-11-20", km: 4), row(3, "2026-11-19", km: nil, strength: true)],
            planned: [.run(plannedRun), .strength(mfit), .strength(trainer)],
            mfitIds: [WorkoutCalendarModel.key(mfit)]
        )
        #expect(days["2026-11-20"]?.ran == true)
        #expect(days["2026-11-20"]?.kilometers == 12)
        #expect(days["2026-11-19"]?.strength == true)
        #expect(days["2026-11-22"]?.plannedRun == true)
        #expect(days["2026-11-24"]?.mfit == true)
        #expect(days["2026-11-21"]?.strength == true && days["2026-11-21"]?.mfit == false)
    }

    @Test func monthSummaryCountsOnlyThatMonth() {
        let rows = [row(1, "2026-11-20", km: 8), row(2, "2026-11-03", km: 10.4), row(3, "2026-10-31", km: 15), row(4, "2026-11-05", km: nil, strength: true)]
        let summary = WorkoutCalendarModel.summary(rows: rows, month: Day(year: 2026, month: 11, day: 1))
        #expect(summary.runs == 2)
        #expect(abs(summary.kilometers - 18.4) < 0.001)
        #expect(summary.strength == 1)
    }

    @Test func monthTitleIsInPortuguese() {
        #expect(WorkoutCalendarModel.title(Day(year: 2026, month: 11, day: 1)) == "Novembro de 2026")
        #expect(WorkoutCalendarModel.shift(Day(year: 2026, month: 12, day: 1), by: 1) == Day(year: 2027, month: 1, day: 1))
        #expect(WorkoutCalendarModel.shift(Day(year: 2026, month: 1, day: 1), by: -1) == Day(year: 2025, month: 12, day: 1))
    }

    @MainActor @Test func calendarRenders() throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        var days: [String: WorkoutCalendarDay] = [:]
        for (iso, km) in [("2026-11-01", 12.0), ("2026-11-03", 8.0), ("2026-11-04", 10.0), ("2026-11-06", 9.0), ("2026-11-08", 18.0), ("2026-11-10", 8.0), ("2026-11-15", 16.0), ("2026-11-20", 8.0)] {
            days[iso] = WorkoutCalendarDay(ran: true, kilometers: km)
        }
        days["2026-11-03"]?.mfit = true
        days["2026-11-05"] = WorkoutCalendarDay(mfit: true)
        days["2026-11-07"] = WorkoutCalendarDay(strength: true)
        days["2026-11-21"] = WorkoutCalendarDay(plannedRun: true, strength: true)
        days["2026-11-22"] = WorkoutCalendarDay(plannedRun: true)
        days["2026-11-24"] = WorkoutCalendarDay(plannedRun: true, mfit: true)
        let today = Day(iso: "2026-11-21")!
        let view = WorkoutCalendarView(month: .constant(Day(year: 2026, month: 11, day: 1)), selected: .constant(today), days: days, today: today)
            .padding(16)
            .frame(width: 440)
            .background(BrandColors.background)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try image.pngData()?.write(to: URL(filePath: dir).appending(path: "workout-calendar.png"))
    }
}
