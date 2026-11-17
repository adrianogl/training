import Testing
@testable import TrainingCore

@Suite struct WorkoutTitleTests {
    @Test func dropsTheRepeatedFirstWord() {
        #expect(WorkoutTitle.clean("Corrida Corrida fácil seg 16/11") == "Corrida fácil seg 16/11")
        #expect(WorkoutTitle.clean("corrida Corrida leve") == "Corrida leve")
    }

    @Test func keepsTitlesWithoutRepetition() {
        #expect(WorkoutTitle.clean("Corrida fácil seg 16/11") == "Corrida fácil seg 16/11")
        #expect(WorkoutTitle.clean("Tiro Tiro") == "Tiro Tiro")
    }

    @Test func comparisonKeyIgnoresWeekdayAndDate() {
        #expect(WorkoutTitle.comparisonKey("Corrida Corrida fácil seg 16/11") == WorkoutTitle.comparisonKey("Corrida Corrida fácil qua 04/11"))
        #expect(WorkoutTitle.comparisonKey("Corrida Longo sáb 15/11") == WorkoutTitle.comparisonKey("Corrida Longo dom 03/05"))
        #expect(WorkoutTitle.comparisonKey("Corrida Corrida fácil seg 16/11") == "corrida fácil")
    }

    @Test func comparisonKeyDropsWeekdayCutByTheNameLimit() {
        #expect(WorkoutTitle.comparisonKey("Corrida Ritmo de maratona ter 26") == "corrida ritmo de maratona")
        #expect(WorkoutTitle.comparisonKey("Corrida Ritmo de meia maratona t") == "corrida ritmo de meia maratona")
        #expect(WorkoutTitle.comparisonKey("Corrida Ritmo de maratona sáb 2") == "corrida ritmo de maratona")
    }

    @Test func comparisonKeyKeepsDistinctWorkoutsApart() {
        #expect(WorkoutTitle.comparisonKey("Corrida Longo sáb 15/11") != WorkoutTitle.comparisonKey("Corrida Corrida fácil seg 16/11"))
        #expect(WorkoutTitle.comparisonKey("Corrida Limiar Anaeróbio Fracio") == "corrida limiar anaeróbio fracio")
        #expect(WorkoutTitle.comparisonKey("Corrida Ritmo de prova 10 Km qua") == "corrida ritmo de prova 10 km")
    }
}
