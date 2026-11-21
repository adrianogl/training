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

    @Test func picksTheCoolestMorningHourAndWarnsAboutHeat() {
        let cool = [(5, 19.0), (6, 17.0), (7, 20.0), (8, 23.0), (9, 27.0), (10, 29.0)].map { HourlyWeather(hour: $0.0, temperature: $0.1, dewPoint: $0.0 < 9 ? -5 : 21) }
        let best = TrainerBestTimeBuilder.make(weather: cool)
        #expect(best?.hour == 6)
        #expect(best?.temperature == 17)
        #expect(best?.heat.isHot == false)
        #expect(best?.laterHotHour == 9)
        #expect(best?.laterBlockReduction == 1_000)
        #expect(TrainerText.heatLater(hour: 9, hasBlocks: false, blockReduction: 1_000) == "A partir das 9h o calor passa a pesar no pace.")
        #expect(TrainerText.heatLater(hour: 9, hasBlocks: true, blockReduction: 1_000) == "A partir das 9h o calor passa a pesar no pace e os blocos ficam 1 km menores.")
        let mild = [(6, 17.0), (9, 22.0)].map { HourlyWeather(hour: $0.0, temperature: $0.1, dewPoint: $0.0 < 9 ? -5 : 18) }
        let mildBest = TrainerBestTimeBuilder.make(weather: mild)
        #expect(mildBest?.laterHotHour == 9)
        #expect(mildBest?.laterBlockReduction == 0)
        #expect(TrainerText.heatLater(hour: 9, hasBlocks: true, blockReduction: 0) == "A partir das 9h o calor passa a pesar no pace.")
        let hot = [(5, 27.0), (6, 27.0), (7, 29.0)].map { HourlyWeather(hour: $0.0, temperature: $0.1, dewPoint: 22) }
        let warm = TrainerBestTimeBuilder.make(weather: hot, longPace: 300)
        #expect(warm?.hour == 5)
        let offset = warm?.heat.paceOffset ?? 0
        #expect(offset > 0)
        #expect(warm?.laterHotHour == nil)
        #expect(TrainerText.heatWarning(warm!.heat, hasBlocks: false) == "Mesmo no horário mais fresco, calor de 27 °C com orvalho de 22 °C: o pace sobe \(offset) s/km.")
        #expect(TrainerText.heatWarning(warm!.heat, hasBlocks: true) == "Mesmo no horário mais fresco, calor de 27 °C com orvalho de 22 °C: o pace sobe \(offset) s/km e os blocos ficam 1 km menores.")
        #expect(TrainerBestTimeBuilder.make(weather: []) == nil)
        #expect(TrainerBestTimeBuilder.make(weather: [HourlyWeather(hour: 15, temperature: 30, dewPoint: nil)]) == nil)
    }

    @Test func writesTheStageCaptionAndTheSuggestion() {
        #expect(TrainerText.longStageCaption(stage: 1, streak: 0) == "etapa 1 de 6 · 1º de 2 para avançar")
        #expect(TrainerText.longStageCaption(stage: 2, streak: 1) == "etapa 2 de 6 · 2º de 2 para avançar")
        #expect(TrainerText.longSuggestion(TrainerLongSuggestion(flagged: 3, total: 4)) == "Sugerido: pausas ou queda de pace em 3 dos últimos 4 longões.")
    }
}
