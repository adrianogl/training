import Foundation
import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct ClaudeAppTests {
    private let today = Day(iso: "2026-11-18")!

    private func input() -> ClaudeContextInput {
        ClaudeContextInput(
            today: today, first: Day(iso: "2026-11-23")!, last: Day(iso: "2026-11-29")!,
            trainerSessions: [TrainerStrengthSession(weekday: 2, group: .core, legLoad: .light, name: "Mob", source: .trainer, intensity: .light, minutes: 25, place: .home)],
            mfit: [1: [.horizontalPush]], runs: [Day(iso: "2026-11-24")!: (.threshold, "Limiar 8 × 1 km")], readiness: [today: 78],
            pain: [.knee], loads: ["agachamento-livre": 60], race: ClaudeRaceTarget(name: "Meia", day: Day(iso: "2026-12-13")!)
        )
    }

    @Test func packageHasEverySectionAndTheWholeCatalog() throws {
        let text = ClaudeContextBuilder.text(input(), extra: "mais glúteo médio")
        for part in ["Pedido do atleta: mais glúteo médio", "Contexto:", "formato_da_resposta:", "\"versao\": 1", "dias_do_treinador", "Limiar 8 × 1 km", "\"knee\""] {
            #expect(text.contains(part), "\(part)")
        }
        let payload = ClaudeContextBuilder.payload(input())
        #expect(payload.catalogo.count == ClaudeContextBuilder.catalog(input()).count)
        #expect(payload.catalogo.count > 500)
        #expect(!payload.catalogo.contains { $0.hasPrefix("SQUAT/GOBLET_SQUAT|") })
        #expect(payload.catalogo.contains("PLANK/PLANK|antiExtension|bodyweight||core,fullBody|i"))
        #expect(text.utf8.count < 120_000)
        #expect(payload.prova?.dia == "2026-12-13")
        #expect(payload.dias_do_treinador.first?.dia_da_semana == "ter")
    }

    @Test func storeAppliesValidDaysAndDropsPastOnes() {
        let store = ClaudeStrengthStore(defaults: UserDefaults(suiteName: "claude-\(UUID())")!)
        let workout = GeneratedStrengthWorkout(weekday: 2, group: .core, intensity: .light, minutes: 25, place: .home, exercises: [], adjustments: [])
        let valid = ClaudeDayResult(rawDay: "2026-11-24", day: Day(iso: "2026-11-24"), why: "porque", workout: workout, errors: [], warnings: [])
        let invalid = ClaudeDayResult(rawDay: "2026-11-25", day: Day(iso: "2026-11-25"), why: nil, workout: workout, errors: [.mfitDay], warnings: [])
        let past = ClaudeDayResult(rawDay: "2026-11-10", day: Day(iso: "2026-11-10"), why: nil, workout: workout, errors: [], warnings: [])
        store.apply([valid, invalid, past], summary: "resumo")
        let loaded = store.load(today: today)
        #expect(Set(loaded.keys) == ["2026-11-24"])
        #expect(loaded["2026-11-24"]?.why == "porque")
        store.removeWeekdays([2], from: today)
        #expect(store.load(today: today).isEmpty)
    }

    @Test func errorsMessageListsEveryProblem() {
        let result = ClaudeDayResult(rawDay: "2026-11-25", day: nil, why: nil, workout: nil, errors: [.mfitDay, .unknownExercise("x")], warnings: [])
        let message = ClaudeContextBuilder.errorsMessage([result])
        #expect(message.contains("2026-11-25: dia do MFIT"))
        #expect(message.contains("\"x\" não existe no catálogo"))
    }
}

@Suite struct ClaudeReplacesMFITAppTests {
    private let workout = GeneratedStrengthWorkout(weekday: 3, group: .core, intensity: .light, minutes: 10, place: .bodyweight, exercises: [], adjustments: [])

    @Test func storesTheReplacementFlag() {
        let store = ClaudeStrengthStore(defaults: UserDefaults(suiteName: "claude-replace-\(UUID())")!)
        var result = ClaudeDayResult(rawDay: "2026-11-25", day: Day(iso: "2026-11-25"), why: nil, workout: workout, errors: [], warnings: [.replacesMFIT])
        result.replacesMFIT = true
        store.apply([result], summary: nil)
        #expect(store.load(today: Day(iso: "2026-11-18")!)["2026-11-25"]?.overridesMFIT == true)
    }

    @Test func oldStoredWorkoutsStillDecode() throws {
        let old = ClaudeStoredWorkout(workout: workout, why: "x", summary: nil)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any] ?? [:]
        json["replacesMFIT"] = nil
        let decoded = try JSONDecoder().decode(ClaudeStoredWorkout.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.overridesMFIT == false)
    }
}
