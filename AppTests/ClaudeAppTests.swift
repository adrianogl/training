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

    @Test func context_includes_notes_for_exercise() throws {
        func note(_ text: String, deleted: Bool = false) -> ExerciseNote {
            ExerciseNote(id: UUID(), exercise: .catalog("SQUAT/GOBLET_SQUAT"), text: text, createdAt: .now, updatedAt: .now, deleted: deleted)
        }
        var withNotes = input()
        withNotes.notes = [note("joelho para fora"), note("apagada", deleted: true)]
        let text = ClaudeContextBuilder.text(withNotes, extra: nil)
        #expect(text.contains("\"observacoes\":{\"SQUAT/GOBLET_SQUAT\":[\"joelho para fora\"]}"))
        #expect(!text.contains("apagada"))
        #expect(!ClaudeContextBuilder.text(input(), extra: nil).contains("\"observacoes\":"))
    }

    @Test func context_caps_notes_per_exercise_and_length() {
        let notes = (0..<25).map { index in
            ExerciseNote(id: UUID(), exercise: .catalog("X"), text: index == 24 ? String(repeating: "a", count: 600) : "n\(index)", createdAt: Date(timeIntervalSince1970: Double(index)), updatedAt: .now, deleted: false)
        }
        let texts = ClaudeContextBuilder.notesByExercise(notes)?["X"] ?? []
        #expect(texts.count == 20)
        #expect(texts.first == "n5")
        #expect(texts.last?.count == 500)
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

@Suite struct ClaudeTextTests {
    @Test func pluralizesInboxCounts() {
        #expect(ClaudeText.inboxCount(total: 1, valid: 0) == "1 dia · 0 válidos · 1 recusado")
        #expect(ClaudeText.inboxCount(total: 3, valid: 1) == "3 dias · 1 válido · 2 recusados")
    }

    @Test func pluralizesApplyButton() {
        #expect(ClaudeText.apply(1) == "Aplicar 1 dia")
        #expect(ClaudeText.apply(2) == "Aplicar 2 dias")
    }
}
