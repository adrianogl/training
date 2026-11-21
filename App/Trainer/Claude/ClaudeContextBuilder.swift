import Foundation
import Insights
import TrainingCore

enum ClaudeContextBuilder {
    static let weekdays = ["seg", "ter", "qua", "qui", "sex", "sab", "dom"]

    static func payload(_ input: ClaudeContextInput) -> ClaudeContextPayload {
        ClaudeContextPayload(
            periodo: .init(inicio: input.first.iso, fim: input.last.iso, hoje: input.today.iso),
            prova: input.race.map { .init(nome: $0.name, dia: $0.day.iso) },
            dias_do_treinador: input.trainerSessions.filter { $0.source == .trainer }.sorted { $0.weekday < $1.weekday }.map {
                .init(dia_da_semana: weekdays[$0.weekday - 1], foco: $0.group.rawValue, intensidade: $0.intensity.rawValue, minutos: $0.minutes, local: $0.place.rawValue)
            },
            mfit: input.mfit.keys.sorted().map { .init(dia_da_semana: weekdays[$0 - 1], padroes: input.mfit[$0]?.map(\.rawValue).sorted() ?? []) },
            corrida: input.runs.keys.sorted().compactMap { day in input.runs[day].map { .init(dia: day.iso, tipo: $0.kind.rawValue, nome: $0.name) } },
            prontidao: input.readiness.keys.sorted().compactMap { day in input.readiness[day].map { .init(dia: day.iso, nota: $0) } },
            dor: input.pain.map(\.rawValue).sorted(),
            ultimas_cargas_kg: input.loads,
            observacoes: notesByExercise(input.notes),
            catalogo_formato: ClaudeText.catalogFormat,
            catalogo: catalog(input).map(StrengthCatalog.contextLine),
            regras: ClaudeText.rules
        )
    }

    static func notesByExercise(_ notes: [ExerciseNote]) -> [String: [String]]? {
        let active = notes.filter { !$0.deleted && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !active.isEmpty else { return nil }
        let grouped = Dictionary(grouping: active, by: { note -> String in
            switch note.exercise {
            case .catalog(let id), .mfit(let id): id
            }
        })
        return grouped.mapValues { group in
            group.sorted { $0.createdAt > $1.createdAt }
                .prefix(ExerciseNotesConstants.maxNotesPerExercise)
                .reversed()
                .map { String($0.text.prefix(ExerciseNotesConstants.maxNoteLength)) }
        }
    }

    static func catalog(_ input: ClaudeContextInput) -> [CatalogExercise] {
        let places = Set(input.trainerSessions.filter { $0.source == .trainer }.map(\.place))
        let wanted = places.isEmpty ? Set(StrengthPlace.allCases) : places
        return StrengthCatalog.all.filter { exercise in
            wanted.contains(where: exercise.fits) && exercise.loads.isDisjoint(with: input.pain)
        }
    }

    static func text(_ input: ClaudeContextInput, extra: String?) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let context = (try? encoder.encode(payload(input))).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        var parts = [ClaudeText.instructions]
        if input.planLocked { parts.append(ClaudeText.planInstruction) }
        if let extra, !extra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Pedido do atleta: \(extra)")
        }
        parts.append("Contexto:\n\(context)")
        parts.append("formato_da_resposta:\n\(ClaudeText.responseFormat)")
        return parts.joined(separator: "\n\n")
    }

    static func errorsMessage(_ results: [ClaudeDayResult]) -> String {
        let lines = results.flatMap { result in result.errors.map { "- \(result.rawDay): \(ClaudeText.issue($0))" } }
        return ([ClaudeText.errorsIntro] + lines).joined(separator: "\n")
    }
}
