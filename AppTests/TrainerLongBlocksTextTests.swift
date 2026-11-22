import Foundation
import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerLongBlocksTextTests {
    private func workout(blocks: [Double]) -> TrainerWorkout {
        var steps: [TrainerStep] = []
        for (index, size) in blocks.enumerated() {
            steps.append(TrainerStep(kind: .steady, meters: 2_000, paceLow: 305, paceHigh: 315))
            steps.append(TrainerStep(kind: .steady, meters: size - 2_000, paceLow: 300, paceHigh: 310))
            if index < blocks.count - 1 { steps.append(TrainerStep(kind: .recovery, meters: 0, restSeconds: 60)) }
        }
        return TrainerWorkout(
            day: Day(iso: "2026-11-28")!, kind: .long, title: "Longão 20 km em blocos", totalMeters: blocks.reduce(0, +), steps: steps,
            paceLow: 300, paceHigh: 310, rationale: ""
        )
    }

    @Test func groupsEqualBlocksIntoASeriesWithTheStandingPause() {
        let rows = TrainerText.stepRows(workout(blocks: [4_000, 4_000, 4_000, 4_000, 4_000]))
        #expect(rows.map(\.title) == ["5×", "Longão", "Pausa parada · água e gel"])
        #expect(rows.map(\.detail) == ["", "4 km · 5:00–5:15/km", "1:00"])
        #expect(rows[0].isHeader)
        #expect(rows[1].isNested && rows[2].isNested)
    }

    @Test func keepsUnequalBlocksAsSeparateRows() {
        let rows = TrainerText.stepRows(workout(blocks: [7_000, 7_000, 6_000]))
        #expect(rows.map(\.title) == ["2×", "Longão", "Pausa parada · água e gel", "Longão"])
        #expect(rows.map(\.isNested) == [false, true, true, false])
        #expect(rows[3].detail == "6 km · 5:00–5:15/km")
        let two = TrainerText.stepRows(workout(blocks: [14_000, 6_000]))
        #expect(two.map(\.title) == ["Longão", "Pausa parada · água e gel", "Longão"])
    }

    @Test func buildsTheShapeWithOneRestBarPerPause() {
        let bars = TrainerText.shapeBars(workout(blocks: [10_000, 10_000]).steps)
        #expect(bars.filter(\.isRest).count == 1)
        #expect(bars.filter { !$0.isRest }.count == 2)
    }

    private var hotSaturday: [HourlyWeather] {
        [(5, 21.0, 19.0), (6, 22, 19), (7, 24, 20), (8, 26, 20), (9, 28, 21), (10, 29, 21), (11, 30, 21), (15, 31, 21), (21, 24, 20), (23, 22, 19)]
            .map { HourlyWeather(hour: $0.0, temperature: $0.1, dewPoint: $0.2) }
    }

    @Test func showsTheUsualHourWithAdaptationAndSuggestsACoolerOne() throws {
        let day = try #require(TrainerHeatDayBuilder.make(weather: hotSaturday, longPace: 310, usualHour: 8, hotSessions: 6))
        let usual = try #require(day.hour(8))

        #expect(day.usualHour == 8)
        #expect(day.hours.map(\.hour) == [5, 6, 7, 8, 9, 10, 11, 15, 21])
        #expect(usual.heat.paceOffset == 9)
        #expect(day.suggestedHour == 6)
        #expect(day.hour(6)?.heat.paceOffset == 6)
        #expect(TrainerText.heatEffect(usual, day: day, hasBlocks: false) == "O pace sobe 9 s/km. Já desconta as 6 corridas no calor das últimas duas semanas.")
        #expect(TrainerText.heatHourLabel(8, usual: true) == "No seu horário, 8h")
        #expect(TrainerText.heatConditions(usual) == "26 °C · orvalho 20 °C")
        #expect(TrainerText.heatSwapConditions(try #require(day.hour(6))) == "22 °C · +6 s/km")
        #expect(TrainerText.heatSwapGain(3) == "3 s/km a menos de ajuste. Toque para ver.")
    }

    @Test func withoutAdaptationTheHeatWeighsMore() throws {
        let adapted = try #require(TrainerHeatDayBuilder.make(weather: hotSaturday, longPace: 310, usualHour: 8, hotSessions: 6))
        let fresh = try #require(TrainerHeatDayBuilder.make(weather: hotSaturday, longPace: 310, usualHour: 8, hotSessions: 0))

        #expect((fresh.hour(8)?.heat.paceOffset ?? 0) > (adapted.hour(8)?.heat.paceOffset ?? 0))
        #expect(TrainerText.heatEffect(try #require(fresh.hour(8)), day: fresh, hasBlocks: false) == "O pace sobe \(fresh.hour(8)?.heat.paceOffset ?? 0) s/km.")
    }

    @Test func sunAddsHeatToTheHour() throws {
        let shade = [HourlyWeather(hour: 9, temperature: 25, dewPoint: 18)]
        let sun = [HourlyWeather(hour: 9, temperature: 25, dewPoint: 18, radiation: 800)]
        let shaded = try #require(TrainerHeatDayBuilder.make(weather: shade, longPace: 310, usualHour: 9))
        let sunny = try #require(TrainerHeatDayBuilder.make(weather: sun, longPace: 310, usualHour: 9))

        #expect((sunny.hour(9)?.heat.paceOffset ?? 0) > (shaded.hour(9)?.heat.paceOffset ?? 0))
    }

    @Test func mildHourHasNoSuggestionAndWarnsLater() throws {
        let mild = [(6, 15.0, 10.0), (8, 17, 10), (10, 26, 19)].map { HourlyWeather(hour: $0.0, temperature: $0.1, dewPoint: $0.2) }
        let day = try #require(TrainerHeatDayBuilder.make(weather: mild, longPace: 310, usualHour: 8))
        let usual = try #require(day.hour(8))

        #expect(day.suggestedHour == nil)
        #expect(!usual.heat.isHot)
        #expect(TrainerText.heatEffect(usual, day: day, hasBlocks: false) == "Sem ajuste de pace nessa hora. A partir das 10h o calor passa a pesar.")
        #expect(TrainerHeatDayBuilder.make(weather: []) == nil)
        #expect(TrainerHeatDayBuilder.make(weather: [HourlyWeather(hour: 23, temperature: 30, dewPoint: 20)]) == nil)
    }

    @Test func usualHourSnapsToTheClosestForecastHour() throws {
        let day = try #require(TrainerHeatDayBuilder.make(weather: hotSaturday, longPace: 310, usualHour: 13))
        #expect(day.usualHour == 11)
    }

    @Test func writesTheStageCaptionAndTheSuggestion() {
        #expect(TrainerText.longStageCaption(stage: 1, streak: 0) == "etapa 1 de 6 · 1º de 2 para avançar")
        #expect(TrainerText.longStageCaption(stage: 2, streak: 1) == "etapa 2 de 6 · 2º de 2 para avançar")
        #expect(TrainerText.longSuggestion(TrainerLongSuggestion(flagged: 3, total: 4)) == "Sugerido: pausas ou queda de pace em 3 dos últimos 4 longões.")
    }
}
