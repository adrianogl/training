import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct TrainerTitlesTests {
    private let today = Day(year: 2026, month: 11, day: 23)
    private let paces = TrainerPaces(easy: 320, long: 315, threshold: 255, vo2max: 238)

    private func workout(_ offset: Int, _ kind: TrainerDayKind, _ title: String, meters: Double, method: TrainerMethod? = nil, variant: TrainerVariant? = nil) -> TrainerWorkout {
        TrainerWorkout(day: today.adding(days: offset), kind: kind, title: title, totalMeters: meters, steps: [], rationale: "", method: method, variant: variant)
    }

    @Test func futureWorkoutsGetTypeAndTotalDistance() {
        let target = TrainerTarget(kind: .text, name: "Correr", text: "correr")
        let workouts = [
            workout(-1, .threshold, "Limiar 4 × 2 km", meters: 11_000, method: .cruiseIntervals),
            workout(0, .threshold, "Limiar 4 × 2 km", meters: 11_000, method: .cruiseIntervals),
            workout(1, .easy, "Rodagem 12 km + 6 × 100 m", meters: 12_000, variant: .strides),
            workout(2, .vo2max, "Subidas 8 × 200 m", meters: 6_000, method: .intervals, variant: .hills),
            workout(3, .threshold, "Tempo contínuo 6 km", meters: 9_000, method: .tempo, variant: .continuousTempo),
            workout(4, .long, "Longão 18 km em blocos", meters: 18_000),
            workout(5, .optionalEasy, "Rodagem opcional 8 km", meters: 8_000),
            workout(6, .off, "Folga", meters: 0),
        ]
        let plan = TrainerPlan(target: target, structure: [:], paces: paces, weeks: [], workouts: workouts, versions: [])
        let titles = TrainerEngine.retitled(plan, from: today).workouts.map(\.title)

        #expect(titles == ["Limiar 4 × 2 km", "Limiar 11 km", "Rodagem 12 km", "Subidas 6 km", "Tempo 9 km", "Longão 18 km", "Opcional 8 km", "Folga"])
    }
}
