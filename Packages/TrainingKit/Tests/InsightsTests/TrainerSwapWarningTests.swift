import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct TrainerSwapWarningTests {
    private let monday = Day(year: 2026, month: 11, day: 30)

    private func workout(_ offset: Int, _ kind: TrainerDayKind, meters: Double = 8_000, method: TrainerMethod? = nil) -> TrainerWorkout {
        TrainerWorkout(day: monday.adding(days: offset), kind: kind, title: "", totalMeters: kind == .off ? 0 : meters, steps: [], rationale: "", method: method)
    }

    private func plan(_ workouts: [TrainerWorkout]) -> TrainerPlan {
        TrainerPlan(
            target: TrainerTarget(kind: .text, name: "Aberto"), structure: [:], paces: TrainerPaces(easy: 300, long: 300, threshold: 250, vo2max: 230),
            weeks: [], workouts: workouts, versions: []
        )
    }

    private var week: TrainerPlan {
        plan([
            workout(0, .easy), workout(1, .threshold, method: .cruiseIntervals), workout(2, .easy), workout(3, .vo2max, method: .intervals),
            workout(4, .optionalEasy), workout(5, .long, meters: 20_000), workout(6, .off),
        ])
    }

    @Test func vo2MovedToTheEveOfTheLongWarns() throws {
        let candidates = [0, 2, 4, 5].map { monday.adding(days: $0) }
        let warning = try #require(TrainerEngine.swapWarning(plan: week, day: monday.adding(days: 3), other: monday.adding(days: 4), candidates: candidates))

        #expect(warning.title == "VO2 na véspera do longão")
        #expect(warning.text == "Sábado tem longão de 20 km. Com o VO2 na sexta, você chega ao longão sem recuperar. Prefira quarta, ou passe o longão para domingo depois de trocar.")
    }

    @Test func longMovedAfterAQualityWarnsWithoutMovingTheLong() throws {
        let candidates = [0, 2, 3, 4].map { monday.adding(days: $0) }
        let warning = try #require(TrainerEngine.swapWarning(plan: week, day: monday.adding(days: 5), other: monday.adding(days: 2), candidates: candidates))

        #expect(warning.title == "Limiar na véspera do longão")
        #expect(warning.text == "Quarta tem longão de 20 km. Com o limiar na terça, você chega ao longão sem recuperar. Prefira quinta.")
    }

    @Test func swapAwayFromTheLongDoesNotWarn() {
        let candidates = [0, 2, 4, 5].map { monday.adding(days: $0) }

        #expect(TrainerEngine.swapWarning(plan: week, day: monday.adding(days: 3), other: monday.adding(days: 2), candidates: candidates) == nil)
        #expect(TrainerEngine.swapWarning(plan: week, day: monday.adding(days: 3), other: monday, candidates: candidates) == nil)
    }

    @Test func easyMovedAwayFromTheEveOfTheLongWarnsForTheQualityThatTakesItsPlace() throws {
        let warning = try #require(TrainerEngine.swapWarning(plan: week, day: monday.adding(days: 4), other: monday.adding(days: 1), candidates: []))

        #expect(warning.title == "Limiar na véspera do longão")
        #expect(warning.text == "Sábado tem longão de 20 km. Com o limiar na sexta, você chega ao longão sem recuperar. Passe o longão para domingo depois de trocar.")
    }
}
