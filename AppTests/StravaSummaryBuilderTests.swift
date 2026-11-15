import Testing
@testable import trAIning

@Suite struct StravaSummaryBuilderTests {
    private static func steps(_ sets: [(count: Int, size: String)]) -> [StravaBlockStep] {
        sets.enumerated().flatMap { index, set in (0..<set.count).map { _ in StravaBlockStep(set: index, size: set.size) } }
    }

    @Test func thresholdWithMixedSets() {
        let input = StravaSummaryInput(kind: .threshold, steps: Self.steps([(6, "1 km"), (3, "1 km")]), workPace: 240, kilometers: 12, paceSeconds: 290, score: 85)

        #expect(StravaSummaryBuilder.text(input) == "Limiar | 6 + 3 × 1 km @ 4:00/km · nota 85\nvia training.aglv.dev")
    }

    @Test func intervalsWithPaceHighlight() {
        let input = StravaSummaryInput(
            kind: .intervals,
            steps: Self.steps([(5, "1 km")]),
            workPace: 228,
            kilometers: 10,
            paceSeconds: 300,
            score: 88,
            similar: [
                StravaSimilar(dateText: "22/10", workPace: 240, kilometers: 9, paceSeconds: 310, heartRate: 160),
                StravaSimilar(dateText: "15/10", workPace: 233, kilometers: 9, paceSeconds: 305, heartRate: 160),
            ]
        )

        #expect(
            StravaSummaryBuilder.text(input)
                == "VO2 máx | 5 × 1 km @ 3:48/km · nota 88\nMelhor VO2 das últimas 6 semanas: 5 s/km mais rápido que em 15/10.\nvia training.aglv.dev"
        )
    }

    @Test func intervalsSlowerThanBestHasNoSecondLine() {
        let input = StravaSummaryInput(
            kind: .intervals,
            steps: Self.steps([(5, "1 km")]),
            workPace: 240,
            kilometers: 10,
            paceSeconds: 300,
            score: 70,
            similar: [StravaSimilar(dateText: "15/10", workPace: 233, kilometers: 9, paceSeconds: 330, heartRate: 160)]
        )

        #expect(StravaSummaryBuilder.text(input) == "VO2 máx | 5 × 1 km @ 4:00/km · nota 70\nvia training.aglv.dev")
    }

    @Test func longRunWithFade() {
        let input = StravaSummaryInput(
            kind: .long,
            kilometers: 22.3,
            paceSeconds: 335,
            heartRate: 150,
            score: 80,
            fadeKm: 17,
            similar: [StravaSimilar(dateText: "1/11", workPace: nil, kilometers: 24, paceSeconds: 330, heartRate: 150)]
        )

        #expect(StravaSummaryBuilder.text(input) == "Longão | 22,3 km @ 5:35/km · nota 80\nPace caiu a partir do km 17.\nvia training.aglv.dev")
    }

    @Test func longestRunHighlight() {
        let input = StravaSummaryInput(
            kind: .long,
            kilometers: 24,
            paceSeconds: 335,
            score: 90,
            fadeKm: 20,
            similar: [StravaSimilar(dateText: "1/11", workPace: nil, kilometers: 21.5, paceSeconds: 330, heartRate: nil)]
        )

        #expect(
            StravaSummaryBuilder.text(input)
                == "Longão | 24,0 km @ 5:35/km · nota 90\nMaior longão das últimas 6 semanas: 24,0 km, 2,5 km a mais que em 1/11.\nvia training.aglv.dev"
        )
    }

    @Test func easyRunWithoutSecondLine() {
        let input = StravaSummaryInput(
            kind: .easy,
            kilometers: 12.7,
            paceSeconds: 275,
            heartRate: 148,
            score: 82,
            similar: [StravaSimilar(dateText: "10/11", workPace: nil, kilometers: 10, paceSeconds: 330, heartRate: 150)]
        )

        #expect(StravaSummaryBuilder.text(input) == "Rodagem | 12,7 km @ 4:35/km · nota 82\nvia training.aglv.dev")
    }

    @Test func easyRunWithLowerHeartRateAtSamePace() {
        let input = StravaSummaryInput(
            kind: .easy,
            kilometers: 8,
            paceSeconds: 330,
            heartRate: 142,
            similar: [StravaSimilar(dateText: "10/11", workPace: nil, kilometers: 8, paceSeconds: 332, heartRate: 150)]
        )

        #expect(StravaSummaryBuilder.text(input) == "Rodagem | 8,0 km @ 5:30/km\nFC 8 bpm mais baixa que em 10/11, no mesmo pace.\nvia training.aglv.dev")
    }

    @Test func missingScoreDropsTheNote() {
        let input = StravaSummaryInput(kind: .easy, kilometers: 5, paceSeconds: 300)

        #expect(StravaSummaryBuilder.text(input) == "Rodagem | 5,0 km @ 5:00/km\nvia training.aglv.dev")
    }

    @Test func raceUsesDistanceAndNoSecondLine() {
        let input = StravaSummaryInput(kind: .race, kilometers: 10, paceSeconds: 255, score: 91, similar: [StravaSimilar(dateText: "1/10", workPace: nil, kilometers: 10, paceSeconds: 258, heartRate: 170)])

        #expect(StravaSummaryBuilder.text(input) == "Prova | 10,0 km @ 4:15/km · nota 91\nvia training.aglv.dev")
    }

    @Test func goalPaceKeepsItsOwnTitleAndBlocks() {
        let input = StravaSummaryInput(kind: .threshold, goalPace: true, steps: Self.steps([(3, "2 km")]), workPace: 255, kilometers: 9, paceSeconds: 300, score: 86)

        #expect(StravaSummaryBuilder.text(input) == "Pace-alvo | 3 × 2 km @ 4:15/km · nota 86\nvia training.aglv.dev")
    }

    @Test func structureNamesDifferentSizesAndSingleBlocks() {
        #expect(StravaSummaryBuilder.structure(Self.steps([(2, "2 km"), (4, "1 km")])) == "2 × 2 km + 4 × 1 km")
        #expect(StravaSummaryBuilder.structure(Self.steps([(1, "20 min")])) == "20 min")
        #expect(StravaSummaryBuilder.structure(Self.steps([(1, "1 km"), (1, "1 km"), (1, "1 km")])) == "3 × 1 km")
    }

    @Test func runWithoutDistanceOrPaceHasNoText() {
        #expect(StravaSummaryBuilder.text(StravaSummaryInput(kind: .easy, kilometers: 0, paceSeconds: nil)) == nil)
    }
}
