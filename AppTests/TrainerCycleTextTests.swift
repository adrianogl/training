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

    @Test func bannersWithOneWeek() {
        let early = Self.review(.keep, start: 1, peak: 1, suggestedStart: 1, suggestedPeak: 1, weeks: 1, endedEarly: true)
        let closed = Self.review(.keep, start: 1, peak: 1, suggestedStart: 1, suggestedPeak: 1, weeks: 1)
        #expect(TrainerCycleText.banner(early, dated: false) == "Você encerrou o ciclo. Veja a análise da 1 semana concluída.")
        #expect(TrainerCycleText.banner(closed, dated: false) == "Fechou 1 semana. Veja como foi e o volume sugerido.")
    }

    @Test func bannerWithoutAClosedWeek() {
        let early = Self.review(.keep, start: 1, peak: 1, suggestedStart: 1, suggestedPeak: 1, weeks: 0, endedEarly: true)
        #expect(TrainerCycleText.banner(early, dated: true) == "Você encerrou o ciclo antes de fechar uma semana.")
        #expect(TrainerCycleText.banner(early, dated: false) == "Você encerrou o ciclo antes de fechar uma semana.")
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
        #expect(TrainerCycleText.endMessage(weeks: 1) == "A análise vai usar a 1 semana já concluída. O plano atual para de gerar treinos.")
    }

    @Test func screenLines() {
        let review = Self.review(.increase, start: 60_000, peak: 80_000, suggestedStart: 64_000, suggestedPeak: 86_000)
        #expect(TrainerCycleText.volumeDone(review) == "0 de 0 km")
        #expect(TrainerCycleText.count(TrainerCycleCount(done: 9, total: 12)) == "9 de 12")
        #expect(TrainerCycleText.longest(24_000) == "Maior longão feito: 24 km")
        #expect(TrainerCycleText.goal(5_700) == "meta 1:35:00")
        #expect(TrainerCycleText.raceDifference(seconds: 5_628, goal: 5_700) == "1:12 abaixo da meta")
        #expect(TrainerCycleText.raceDifference(seconds: 5_772, goal: 5_700) == "1:12 acima da meta")
        #expect(TrainerCycleText.readinessCaption(72.4) == "72 no início")
        #expect(TrainerCycleText.lowReadinessCaption(60) == "abaixo de 60")
        #expect(TrainerCycleText.longsMissedCaption(1) == "de 1 longão")
        #expect(TrainerCycleText.longsMissedCaption(12) == "de 12 longões")
        let change = TrainerCycleChange(meters: 10_000, first: 2_460, last: 2_412)
        #expect(TrainerCycleText.predictionTitle(10_000) == "Previsão 10 km")
        #expect(TrainerCycleText.predictionCaption(change) == "era 41:00 no início")
        #expect(TrainerCycleText.predictionDelta(change) == "−0:48")
        #expect(TrainerCycleText.predictionDelta(TrainerCycleChange(meters: 5_000, first: 1_200, last: 1_230)) == "+0:30")
        #expect(TrainerCycleText.predictionDelta(TrainerCycleChange(meters: 5_000, first: 1_200, last: 1_200)) == "sem mudança")
    }

    @Test func resultLines() {
        var review = Self.review(.increase, start: 60_000, peak: 80_000, suggestedStart: 64_000, suggestedPeak: 86_000)
        review.weeks = [TrainerCycleWeek(index: 0, start: Self.day, doneMeters: 806_000, plannedMeters: 833_000)]
        #expect(TrainerCycleText.resultValue(review, goalMeters: nil) == "806 de 833 km")
        #expect(TrainerCycleText.resultCaption(review, goalMeters: nil) == "97% do previsto")
        review.predictions = [
            TrainerCycleChange(meters: 5_000, first: 1_200, last: 1_180),
            TrainerCycleChange(meters: 10_000, first: 2_460, last: 2_412),
        ]
        #expect(TrainerCycleText.resultValue(review, goalMeters: nil) == "40:12")
        #expect(TrainerCycleText.resultCaption(review, goalMeters: nil) == "previsão 10 km · 806 de 833 km")
        #expect(TrainerCycleText.resultValue(review, goalMeters: 5_000) == "19:40")
        review.raceSeconds = 5_628
        review.goalSeconds = 5_700
        #expect(TrainerCycleText.resultValue(review, goalMeters: 21_097.5) == "1:33:48")
        #expect(TrainerCycleText.resultCaption(review, goalMeters: 21_097.5) == "meta 1:35:00")
    }

    @Test func resultWithoutWeeksLeavesVolumeOut() {
        var review = Self.review(.keep, start: 60_000, peak: 80_000, suggestedStart: 60_000, suggestedPeak: 80_000, weeks: 0)
        #expect(TrainerCycleText.resultValue(review, goalMeters: nil) == nil)
        #expect(TrainerCycleText.resultCaption(review, goalMeters: nil) == nil)
        review.predictions = [TrainerCycleChange(meters: 10_000, first: 2_460, last: 2_412)]
        #expect(TrainerCycleText.resultValue(review, goalMeters: nil) == "40:12")
        #expect(TrainerCycleText.resultCaption(review, goalMeters: nil) == "previsão 10 km")
        review.raceSeconds = 5_628
        review.goalSeconds = nil
        #expect(TrainerCycleText.resultCaption(review, goalMeters: nil) == nil)
    }

    @Test func chartLabel() {
        var review = Self.review(.keep, start: 1, peak: 1, suggestedStart: 1, suggestedPeak: 1, weeks: 0)
        review.weeks = [TrainerCycleWeek(index: 0, start: Self.day, doneMeters: 806_000, plannedMeters: 833_000)]
        #expect(TrainerCycleText.chartLabel(review) == "806 de 833 km, 97% do previsto")
    }

    @Test func summaryLines() {
        func summary(_ verdict: TrainerCycleVerdict, after: Double, result: Double?) -> TrainerCycleSummary {
            TrainerCycleSummary(title: "t", first: Self.day, last: Self.day, verdict: verdict, beforePeakMeters: 80_000, afterPeakMeters: after, resultSeconds: result)
        }
        #expect(TrainerCycleText.summaryLine(summary(.increase, after: 86_000, result: nil)) == "Aumentou de 80 para 86 km")
        #expect(TrainerCycleText.summaryLine(summary(.keep, after: 80_000, result: nil)) == "Manteve 80 km")
        #expect(TrainerCycleText.summaryLine(summary(.decrease, after: 72_000, result: 5_628)) == "Diminuiu de 80 para 72 km · 1:33:48")
        #expect(TrainerCycleText.summaryLine(summary(.increase, after: 55_000, result: nil)) == "Diminuiu de 80 para 55 km")
        #expect(TrainerCycleText.summaryLine(summary(.decrease, after: 90_000, result: nil)) == "Aumentou de 80 para 90 km")
        #expect(TrainerCycleText.summaryLine(summary(.increase, after: 80_000, result: nil)) == "Manteve 80 km")
    }
}
