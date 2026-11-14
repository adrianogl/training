import Testing
@testable import trAIning

@Suite struct RaceLessonTests {
    private static func splits(_ paces: [Double]) -> [RaceSplit] {
        paces.enumerated().map { RaceSplit(index: $0.offset, distance: 1_000, pace: $0.element, planned: nil) }
    }

    @Test func positiveSplitSuggestsSlowerStart() {
        let paces = [290.0, 290, 290, 290, 290, 298, 298, 298, 298, 298]
        let columns = RaceLesson.columns(resultSeconds: 2_960, goalSeconds: 2_900, eveSeconds: 2_950, splits: Self.splits(paces))

        #expect(columns.negative.map(\.text) == ["1:00 acima da meta", "Ritmo caiu 8 s/km na segunda metade"])
        #expect(columns.negative[0].why.contains("49:10"))
        #expect(columns.negative[1].evidence == "km 1–5: 4:50 · km 6–10: 4:58")
        #expect(columns.positive.isEmpty)
        #expect(columns.expected.map(\.text) == [
            "Definir a meta pela previsão da véspera",
            "Largar 4 s/km mais lento nos primeiros 5 km",
        ])
        #expect(columns.expected[1].evidence == "alvo 4:54/km nos primeiros 5 km")
        #expect(Set((columns.negative + columns.expected).map(\.id)).count == 4)
    }

    @Test func fasterThanEveWithStrongFinish() {
        let paces = [300.0, 300, 300, 300, 290]
        let columns = RaceLesson.columns(resultSeconds: 1_490, goalSeconds: 1_500, eveSeconds: 1_520, splits: Self.splits(paces))

        #expect(columns.positive.map(\.text) == [
            "0:10 abaixo da meta",
            "0:30 melhor que a previsão da véspera",
            "Segunda metade 3 s/km mais rápida",
            "Último km a 4:50 (−10 s/km vs. o resto)",
        ])
    }

    @Test func evenRaceOnGoalRepeatsStrategy() {
        let columns = RaceLesson.columns(resultSeconds: 3_000, goalSeconds: 3_002, eveSeconds: nil, splits: Self.splits([300, 300, 301, 300]))

        #expect(columns.negative.isEmpty)
        #expect(columns.positive.map(\.text) == ["Ritmo constante nas duas metades"])
        #expect(columns.expected.map(\.text) == ["Repetir a mesma estratégia"])
    }

    @Test func noResultHasNoLesson() {
        let columns = RaceLesson.columns(resultSeconds: nil, goalSeconds: 3_000, eveSeconds: nil, splits: [])

        #expect(columns.negative.isEmpty && columns.positive.isEmpty && columns.expected.isEmpty)
    }
}
