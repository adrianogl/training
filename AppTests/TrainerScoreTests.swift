import Foundation
import GarminAPI
import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerScoreTests {
    private let monday = Day(year: 2026, month: 11, day: 23)

    @Test func mapsRepeatGroupIntoWorkAndRestSteps() throws {
        let group = PlannedStep(
            kind: .other, repeats: 8,
            children: [
                PlannedStep(kind: .active, meters: 1_000, target: .pace(fastest: 241, slowest: 255)),
                PlannedStep(kind: .recovery, seconds: 40),
            ]
        )
        let planned = PlannedWorkout(
            id: 1, day: monday.adding(days: 1).iso, title: "Limiar", estimatedSeconds: nil, estimatedMeters: 12_000,
            steps: [PlannedStep(kind: .warmup, meters: 2_000), group, PlannedStep(kind: .cooldown, meters: 2_000)]
        )
        let result = try #require(TrainerExternalMapper.convert(planned))
        let work = try #require(result.steps.first { $0.kind == .work })
        let rest = try #require(result.steps.first { $0.kind == .recovery })

        #expect(result.day == monday.adding(days: 1))
        #expect(result.totalMeters == 12_000)
        #expect(work.repeats == 8 && work.meters == 1_000)
        #expect(work.paceLow == 241 && work.paceHigh == 255)
        #expect(rest.repeats == 7 && rest.restSeconds == 40)
    }

    @Test func dropsWorkoutsWithInvalidDay() {
        let planned = PlannedWorkout(id: 1, day: "x", title: "Rodagem", estimatedSeconds: nil, estimatedMeters: 5_000, steps: [])

        #expect(TrainerExternalMapper.convert(planned) == nil)
    }

    @Test func formatsScoreboardLines() {
        let board = TrainerScoreboard(
            weekIndex: 2, start: monday, doneMeters: 63_000, plannedMeters: 65_000, qualityOnTarget: 3, qualityTotal: 4,
            longClosed: true, longBlocks: true, predictionDeltaSeconds: -18, predictionMeters: 21_097.5
        )

        #expect(TrainerText.scoreboardTitle(2) == "Placar · semana 2")
        #expect(TrainerText.scoreboardKilometers(board) == "63/65 km")
        #expect(TrainerText.scoreboardQuality(board) == "3 de 4 no alvo")
        #expect(TrainerText.scoreboardPrediction(board) == "−18 s previsão 21 km")
        #expect(TrainerText.scoreboardLong(board) == "Longão em blocos fechou")
        #expect(TrainerText.scoreboardRow(board) == "S2 · 63/65 km · 3/4 no alvo · −18 s")
    }

    @Test func formatsReadinessSuggestion() {
        let factor = TrainerReadinessFactor(name: "sono", value: 61)
        let swap = TrainerReadinessSuggestion(day: monday, score: 42, factor: factor, workoutTitle: "VO2 máx 5 × 1 km", swapDay: monday.adding(days: 1))
        let keep = TrainerReadinessSuggestion(day: monday, score: 42, factor: nil, workoutTitle: "Longão 20 km", swapDay: nil)

        #expect(TrainerText.readinessSuggestionText(swap) == "Prontidão 42 com sono 61. Sugestão: rodagem leve de 8 km hoje e VO2 máx 5 × 1 km amanhã.")
        #expect(TrainerText.readinessSuggestionText(keep) == "Prontidão 42. Sugestão: rodagem leve de 8 km hoje e manter o resto da semana.")
    }
}
