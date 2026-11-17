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
}
