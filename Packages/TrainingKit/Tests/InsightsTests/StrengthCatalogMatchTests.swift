import Testing
@testable import Insights

@Suite struct StrengthCatalogMatchTests {
    @Test func everyAliasPointsToACatalogExercise() {
        for alias in StrengthCatalogMatchConstants.aliases {
            #expect(StrengthCatalog.exercise(alias.id) != nil, "\(alias.id)")
        }
    }

    @Test(arguments: [
        ("Supino reto com halteres", "BENCH_PRESS/DUMBBELL_BENCH_PRESS"),
        ("Supino inclinado com barra", "BENCH_PRESS/INCLINE_BARBELL_BENCH_PRESS"),
        ("Remada unilateral com halter", "ROW/SINGLE_ARM_NEUTRAL_GRIP_DUMBBELL_ROW"),
        ("Puxada aberta na polia", "PULL_UP/WIDE_GRIP_LAT_PULLDOWN"),
        ("Tríceps corda", "TRICEPS_EXTENSION/ROPE_PRESSDOWN"),
        ("Elevação lateral com halteres", "LATERAL_RAISE/DUMBBELL_LATERAL_RAISE"),
        ("Mesa flexora", "LEG_CURL/LEG_CURL"),
        ("Prancha", "PLANK/PLANK"),
        ("Afundo com halteres", "LUNGE/DUMBBELL_LUNGE"),
    ])
    func knownNamesFindTheirExercise(name: String, id: String) {
        #expect(StrengthCatalogMatch.exercise(named: name)?.id == id)
    }

    @Test func unknownMachineStaysWithoutName() {
        #expect(StrengthCatalogMatch.exercise(named: "Cadeira abdutora") == nil)
    }

    @Test func strictFallbackNeedsEveryWordAndNoExtraModifier() {
        #expect(StrengthCatalogMatch.exercise(named: "Crucifixo com halteres inclinado")?.id == "FLYE/INCLINE_DUMBBELL_FLYE")
        #expect(StrengthCatalogMatch.exercise(named: "Movimento inventado") == nil)
    }
}
