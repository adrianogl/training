import Foundation
import GarminAPI
import Insights
import MFIT
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerMFITTests {
    private let monday = Day(iso: "2026-11-16")!

    private func block(_ category: String, sets: Int) -> StrengthBlock {
        StrengthBlock(exercises: [StrengthExercise(name: category, detail: nil, category: category, exerciseKey: nil, reps: 10, seconds: nil)], sets: sets, restSeconds: 60)
    }

    @Test func mapsMFITWorkoutsToTrainerStrengthDays() {
        let program = MFITProgram(id: 1, title: "Treino 7", start: "2026-11-13", end: "2026-12-18", workouts: [
            MFITWorkout(id: 10, title: "Superiores", order: 0, blocks: [block("BENCH_PRESS", sets: 10), block("CALF_RAISE", sets: 3)], completions: []),
            MFITWorkout(id: 11, title: "MMII", order: 1, blocks: [block("SQUAT", sets: 10), block("PLANK", sets: 3)], completions: []),
            MFITWorkout(id: 12, title: "Full Body", order: 2, blocks: [block("ROW", sets: 3), block("DEADLIFT", sets: 3), block("PLANK", sets: 6)], completions: []),
        ])
        let schedule = StrengthSchedule(defaults: UserDefaults(suiteName: "trainer-mfit-\(UUID())")!)
        let sessions = TrainerMFITStrength.sessions(program: program, schedule: schedule)
        #expect(sessions.map(\.weekday) == [1, 3, 5])
        #expect(sessions.map(\.group) == [.upper, .lower, .fullBody])
        #expect(sessions.map(\.legLoad) == [.light, .heavy, .light])
        #expect(sessions.map(\.name) == ["Superiores", "MMII", "Full Body"])
        #expect(sessions.allSatisfy { $0.source == .mfit })
        #expect(StrengthSessions.sameMFIT(sessions, TrainerMFITStrength.sessions(program: program, schedule: schedule)))
        #expect(TrainerMFITStrength.caption(sessions[1]) == "pernas · perna pesada")
    }

    private func plan() -> TrainerPlan {
        let workouts: [TrainerWorkout] = [
            TrainerWorkout(day: monday, kind: .easy, title: "Rodagem 9 km", totalMeters: 9_000, steps: [], rationale: ""),
            TrainerWorkout(day: monday.adding(days: 1), kind: .easy, title: "Rodagem 9 km", totalMeters: 9_000, steps: [], rationale: ""),
            TrainerWorkout(day: monday.adding(days: 2), kind: .easy, title: "Rodagem 9 km", totalMeters: 9_000, steps: [], rationale: ""),
            TrainerWorkout(day: monday.adding(days: 3), kind: .vo2max, title: "VO2 máx 5 × 1 km", totalMeters: 9_000, steps: [], rationale: ""),
            TrainerWorkout(day: monday.adding(days: 5), kind: .long, title: "Longão 19 km", totalMeters: 19_000, steps: [], rationale: ""),
        ]
        return TrainerPlan(
            target: TrainerTarget(kind: .race, name: "Meia", date: monday.adding(days: 60), distanceMeters: 21_097, goalSeconds: 5_400),
            structure: [:],
            paces: TrainerPaces(easy: 340, long: 335, threshold: 290, vo2max: 265, thresholdSource: .work, vo2Source: .prediction),
            weeks: [],
            workouts: workouts,
            versions: [],
            strength: [
                TrainerStrengthSession(weekday: 1, group: .upper, legLoad: .light, name: "Superiores"),
                TrainerStrengthSession(weekday: 3, group: .lower, legLoad: .heavy, name: "MMII"),
            ]
        )
    }

    @Test func suggestsSwappingQualityAwayFromHeavyLegDay() throws {
        let swap = try #require(TrainerLegSwapFinder.find(plan: plan(), today: monday, kept: []))
        #expect(swap.quality.day == monday.adding(days: 3))
        #expect(swap.easy.day == monday.adding(days: 1))
        #expect(swap.strengthName == "MMII")
        #expect(TrainerMFITText.swapHeadline(swap) == "VO2 máx 5 × 1 km de quinta cai no dia seguinte ao MMII de quarta.")

        let next = TrainerLegSwapFinder.apply(swap, to: plan(), now: .now)
        #expect(next.workouts.first { $0.day == monday.adding(days: 1) }?.kind == .vo2max)
        #expect(next.workouts.first { $0.day == monday.adding(days: 3) }?.kind == .easy)
        #expect(next.versions.last?.summary == "VO2 máx 5 × 1 km foi para terça e a rodagem para quinta, para não cair no dia seguinte ao MMII de quarta.")
        #expect(TrainerLegSwapFinder.find(plan: next, today: monday, kept: []) == nil)
        #expect(TrainerLegSwapFinder.find(plan: plan(), today: monday, kept: [monday.adding(days: 3).iso]) == nil)
    }
}
