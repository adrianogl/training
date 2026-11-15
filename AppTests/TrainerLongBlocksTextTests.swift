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
        #expect(rows.map(\.title) == ["2×", "Longão", "Pausa parada · água e gel", "Pausa parada · água e gel", "Longão"])
        #expect(rows.map(\.isNested) == [false, true, true, false, false])
        #expect(rows[4].detail == "6 km · 5:00–5:15/km")
        let two = TrainerText.stepRows(workout(blocks: [14_000, 6_000]))
        #expect(two.map(\.title) == ["Longão", "Pausa parada · água e gel", "Longão"])
    }

    @Test func buildsTheShapeWithOneRestBarPerPause() {
        let bars = TrainerText.shapeBars(workout(blocks: [10_000, 10_000]).steps)
        #expect(bars.filter(\.isRest).count == 1)
    }

    @Test func picksTheCoolestMorningHourAndWarnsAboutHeat() {
        let cool = [(5, 19.0), (6, 17.0), (7, 20.0), (8, 23.0), (9, 25.0), (10, 27.0)].map { HourlyWeather(hour: $0.0, temperature: $0.1, dewPoint: nil) }
        let best = TrainerBestTimeBuilder.make(weather: cool)
        #expect(best?.hour == 6)
        #expect(best?.temperature == 17)
        #expect(best?.heat.isHot == false)
        #expect(best?.laterHotHour == 9)
        let hot = [(5, 26.0), (6, 25.5), (7, 28.0)].map { HourlyWeather(hour: $0.0, temperature: $0.1, dewPoint: nil) }
        let warm = TrainerBestTimeBuilder.make(weather: hot)
        #expect(warm?.hour == 6)
        #expect(warm?.heat.paceOffset == 5)
        #expect(warm?.laterHotHour == nil)
        #expect(TrainerBestTimeBuilder.make(weather: []) == nil)
        #expect(TrainerBestTimeBuilder.make(weather: [HourlyWeather(hour: 15, temperature: 30, dewPoint: nil)]) == nil)
    }

    @Test func writesTheStageCaptionAndTheSuggestion() {
        #expect(TrainerText.longStageCaption(stage: 1, streak: 0) == "etapa 1 de 6 · 1º de 2 para avançar")
        #expect(TrainerText.longStageCaption(stage: 2, streak: 1) == "etapa 2 de 6 · 2º de 2 para avançar")
        #expect(TrainerText.longSuggestion(TrainerLongSuggestion(flagged: 3, total: 4)) == "Sugerido: pausas ou queda de pace em 3 dos últimos 4 longões.")
    }
}
