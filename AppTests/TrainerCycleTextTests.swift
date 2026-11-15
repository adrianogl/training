import Foundation
import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerCycleTextTests {
    private static let day = Day(iso: "2026-11-17")!

    private static func review(_ verdict: TrainerCycleVerdict, start: Double, peak: Double, suggestedStart: Double, suggestedPeak: Double, weeks: Int = 4, endedEarly: Bool = false) -> TrainerCycleReview {
        TrainerCycleReview(
            first: day, last: day, endedEarly: endedEarly,
            weeks: (0..<weeks).map { TrainerCycleWeek(index: $0, start: day, doneMeters: 1, plannedMeters: 1) },
            long: TrainerCycleCount(done: 0, total: 0), threshold: TrainerCycleCount(done: 0, total: 0),
            vo2: TrainerCycleCount(done: 0, total: 0), mediumLong: TrainerCycleCount(done: 0, total: 0),
            longestLongMeters: nil, longestLongPlannedMeters: nil, readinessFirst: nil, readinessLast: nil,
            lowReadinessDays: 0, extraLightWeeks: [], longsMissed: 0, predictions: [], raceSeconds: nil, goalSeconds: nil,
            verdict: verdict, reasons: [], currentStartMeters: start, currentPeakMeters: peak,
            suggestedStartMeters: suggestedStart, suggestedPeakMeters: suggestedPeak
        )
    }

    private static let increase = review(.increase, start: 60_000, peak: 80_000, suggestedStart: 64_000, suggestedPeak: 86_000)
    private static let keep = review(.keep, start: 60_000, peak: 80_000, suggestedStart: 60_000, suggestedPeak: 80_000)
    private static let decrease = review(.decrease, start: 60_000, peak: 80_000, suggestedStart: 54_000, suggestedPeak: 72_000)

    @Test func suggestionWithDate() {
        #expect(TrainerCycleText.suggestionLine(Self.increase, dated: true) == "Sugestão: aumentar o pico de 80 para 86 km")
        #expect(TrainerCycleText.suggestionLine(Self.keep, dated: true) == "Sugestão: manter o pico em 80 km")
        #expect(TrainerCycleText.suggestionLine(Self.decrease, dated: true) == "Sugestão: diminuir o pico de 80 para 72 km")
    }

    @Test func suggestionWithoutDate() {
        #expect(TrainerCycleText.suggestionLine(Self.increase, dated: false) == "Sugestão: aumentar de 60 para 64 km")
        #expect(TrainerCycleText.suggestionLine(Self.keep, dated: false) == "Sugestão: manter 60 km")
        #expect(TrainerCycleText.suggestionLine(Self.decrease, dated: false) == "Sugestão: diminuir de 60 para 54 km")
    }

    @Test func volumes() {
        #expect(TrainerCycleText.volumes(Self.increase, dated: true) == "Início 60 → 64 km · pico 80 → 86 km")
        #expect(TrainerCycleText.volumes(Self.keep, dated: true) == "Início 60 km · pico 80 km, como neste ciclo")
        #expect(TrainerCycleText.volumes(Self.increase, dated: false) == "Base 60 → 64 km · pico 80 → 86 km")
        #expect(TrainerCycleText.volumes(Self.keep, dated: false) == "Base 60 km · pico 80 km, como neste ciclo")
    }

    @Test func banners() {
        #expect(TrainerCycleText.banner(Self.increase, dated: true) == "A prova terminou. Veja como foi e o volume sugerido.")
        #expect(TrainerCycleText.banner(Self.increase, dated: false) == "Fechou 4 semanas. Veja como foi e o volume sugerido.")
        let early = Self.review(.keep, start: 1, peak: 1, suggestedStart: 1, suggestedPeak: 1, weeks: 3, endedEarly: true)
        #expect(TrainerCycleText.banner(early, dated: true) == "Você encerrou o ciclo. Veja a análise das 3 semanas concluídas.")
    }

    @Test func verdictTitles() {
        #expect(TrainerCycleText.verdictTitle(.increase) == "Aumentar o volume")
        #expect(TrainerCycleText.verdictTitle(.keep) == "Manter o volume")
        #expect(TrainerCycleText.verdictTitle(.decrease) == "Diminuir o volume")
    }

    @Test func reasons() {
        #expect(TrainerCycleText.reason(.volume(share: 0.97, weeksBelow: 1)) == "Cumpriu 97% do volume, 1 semana abaixo do previsto.")
        #expect(TrainerCycleText.reason(.volume(share: 1, weeksBelow: 0)) == "Cumpriu 100% do volume, nenhuma semana abaixo do previsto.")
        #expect(TrainerCycleText.reason(.readiness(first: 72, last: 75)) == "Prontidão média foi de 72 para 75.")
        #expect(TrainerCycleText.reason(.lightWeeks(2)) == "2 semanas leves fora do previsto.")
        #expect(TrainerCycleText.reason(.race(seconds: 5_628, goal: 5_700)) == "Fez a prova 1:12 abaixo da meta.")
        #expect(TrainerCycleText.reason(.race(seconds: 5_772, goal: 5_700)) == "Fez a prova 1:12 acima da meta.")
        #expect(TrainerCycleText.reason(.tooShort(weeks: 3)) == "Só 3 semanas concluídas, pouco para mudar o volume.")
        #expect(TrainerCycleText.reason(.noProgress) == "Cumpriu o volume, mas a previsão não melhorou.")
    }

    @Test func predictionReasons() {
        let better = TrainerCycleChange(meters: 10_000, first: 3_000, last: 2_928)
        let worse = TrainerCycleChange(meters: 21_097.5, first: 6_000, last: 6_072)
        #expect(TrainerCycleText.reason(.prediction(better)) == "A previsão de 10 km caiu 1:12.")
        #expect(TrainerCycleText.reason(.prediction(worse)) == "A previsão de meia subiu 1:12.")
        #expect(TrainerCycleText.reason(.prediction(TrainerCycleChange(meters: 42_195, first: 1, last: 2))) == "A previsão de maratona subiu 0:01.")
        #expect(TrainerCycleText.reason(.prediction(TrainerCycleChange(meters: 5_000, first: 100, last: 90))) == "A previsão de 5 km caiu 0:10.")
        #expect(TrainerCycleText.reason(.prediction(TrainerCycleChange(meters: 15_000, first: 100, last: 90))) == "A previsão de 15 km caiu 0:10.")
    }

    @Test func endMessage() {
        #expect(TrainerCycleText.endMessage(weeks: 5) == "A análise vai usar as 5 semanas já concluídas. O plano atual para de gerar treinos.")
    }

    @Test func summaryLines() {
        func summary(_ verdict: TrainerCycleVerdict, after: Double, result: Double?) -> TrainerCycleSummary {
            TrainerCycleSummary(title: "t", first: Self.day, last: Self.day, verdict: verdict, beforePeakMeters: 80_000, afterPeakMeters: after, resultSeconds: result)
        }
        #expect(TrainerCycleText.summaryLine(summary(.increase, after: 86_000, result: nil)) == "Aumentou de 80 para 86 km")
        #expect(TrainerCycleText.summaryLine(summary(.keep, after: 80_000, result: nil)) == "Manteve 80 km")
        #expect(TrainerCycleText.summaryLine(summary(.decrease, after: 72_000, result: 5_628)) == "Diminuiu de 80 para 72 km · 1:33:48")
    }
}
