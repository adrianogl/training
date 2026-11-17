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
            catalogo: StrengthCatalog.all.map {
                .init(
                    id: $0.id, nome: $0.name, padrao: $0.pattern.rawValue, equipamento: $0.equipment.rawValue,
                    regioes: $0.loads.map(\.rawValue).sorted(), focos: $0.focus.map(\.rawValue).sorted(), unilateral: $0.unilateral, isometria: $0.timed
                )
            },
            regras: ClaudeText.rules
        )
    }

    static func text(_ input: ClaudeContextInput, extra: String?) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let context = (try? encoder.encode(payload(input))).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
        var parts = [ClaudeText.instructions]
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
