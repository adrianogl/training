import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerFullPlanTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func run(_ id: Int64, _ day: Day, km: Double, pace: Double, kind: RunKind) -> TrainerRun {
        TrainerRun(activityId: id, day: day, meters: km * 1_000, seconds: km * pace, kind: kind)
    }

    private var history: TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(run(base + 1, start, km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 2, start.adding(days: 1), km: 10, pace: 262, kind: .tempo))
            runs.append(run(base + 3, start.adding(days: 2), km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 4, start.adding(days: 5), km: Double(18 - week), pace: 335, kind: .long))
        }
        return TrainerHistory(runs: runs, predictions: [10_000: 2_580, 5_000: 1_230])
    }

    private func create(weeks: Int, distance: Double, goal: Double) -> TrainerPlan {
        let race = monday.adding(days: (weeks - 1) * 7 + 5)
        let target = TrainerTarget(kind: .race, name: "Prova", date: race, distanceMeters: distance, goalSeconds: goal)
        return TrainerEngine.create(
            target: target, structure: TrainerEngine.defaultStructure, strength: [], history: history, today: monday, now: now
        )
    }

    @Test func halfMarathonHasWorkoutsInEveryWeek() {
        let plan = create(weeks: 13, distance: 21_097.5, goal: 5_700)

        #expect(plan.weeks.count == 13)
        for week in plan.weeks {
            let days = plan.workouts.filter { $0.day.weekStart == week.start }
            #expect(days.count == 7)
            #expect(abs(week.plannedMeters - days.reduce(0) { $0 + $1.totalMeters }) < 1)
        }
    }

    @Test func openEndedPlanDetailsTheRollingHorizon() {
        let target = TrainerTarget(kind: .text, name: "Correr mais")
        let plan = TrainerEngine.create(
            target: target, structure: TrainerEngine.defaultStructure, strength: [], history: history, today: monday, now: now
        )

        #expect(plan.weeks.count == 12)
        #expect(plan.workouts.count == 12 * 7)
    }

    @Test func adjustKeepsDistantWeeksCoherentAndGroupsTheDiff() throws {
        let plan = create(weeks: 13, distance: 21_097.5, goal: 5_700)
        let today = monday.adding(days: 7)
        let request = TrainerRequest(category: .fatigue, text: "cansaço", from: today)

        let adjusted = TrainerEngine.adjust(plan, history: history, today: today, now: now, trigger: .request(request))

        #expect(adjusted.workouts.count == plan.workouts.count)
        #expect(adjusted.workouts.filter { $0.day < today } == plan.workouts.filter { $0.day < today })
        let changes = try #require(adjusted.versions.last?.changes)
        let limit = today.adding(days: 15)
        #expect(!changes.contains { ($0.day.map { $0 >= limit } ?? false) && $0.kind != .unchanged })
        let grouped = changes.filter { $0.title.contains("treino") && $0.title.hasPrefix("Semana") }
        #expect(!grouped.isEmpty)
        #expect(grouped.allSatisfy { $0.day == nil && $0.weekIndex != nil })
        for week in adjusted.weeks where week.start >= today.weekStart {
            let days = adjusted.workouts.filter { $0.day.weekStart == week.start }
            #expect(abs(week.plannedMeters - days.reduce(0) { $0 + $1.totalMeters }) < 1)
        }
    }

    @Test func marathonPlanStaysBelowTheSyncLimit() throws {
        var plan = create(weeks: 24, distance: 42_195, goal: 12_600)
        let size = try JSONEncoder().encode(plan).count
        for index in 1...6 {
            plan = TrainerEngine.adjust(
                plan, history: history, today: monday.adding(days: 7 * index), now: now, trigger: .weekEnded(index)
            )
        }
        let grown = try JSONEncoder().encode(plan).count
        print("marathon-json-bytes fresh=\(size) afterSixAdjusts=\(grown) workouts=\(plan.workouts.count)")

        #expect(plan.weeks.count == 24)
        #expect(plan.workouts.count == 24 * 7)
        #expect(grown < 950_000)
    }

    @Test func fillMissingWeeksCompletesTruncatedPlanWithoutVersion() throws {
        let full = create(weeks: 13, distance: 21_097.5, goal: 5_700)
        var truncated = full
        truncated.workouts = full.workouts.filter { $0.day < monday.adding(days: 15) }

        let filled = try #require(TrainerEngine.fillMissingWeeks(truncated, history: history, today: monday))

        #expect(filled.versions == truncated.versions)
        #expect(filled.workouts.filter { $0.day < monday.adding(days: 15) } == truncated.workouts)
        for week in filled.weeks {
            let days = filled.workouts.filter { $0.day.weekStart == week.start }
            #expect(days.count == 7)
        }
        #expect(filled.weeks.prefix(2) == truncated.weeks.prefix(2))
        #expect(filled.weeks.dropFirst(2).allSatisfy { $0.plannedMeters > 0 })
    }

    @Test func fillMissingWeeksReturnsNilForCompletePlan() {
        let plan = create(weeks: 13, distance: 21_097.5, goal: 5_700)

        #expect(TrainerEngine.fillMissingWeeks(plan, history: history, today: monday) == nil)
    }
}
