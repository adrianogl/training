import Testing
@testable import Narrative

private struct FixedFeedback: FeedbackGenerator {
    let text: String
    func generate(instructions: String, prompt: String) async throws -> String { text }
}

@Suite struct CoachFeedbackTests {
    private let facts = [
        "Bom treino: 7 dos 9 tiros de 1000 m saíram no alvo, com média de 3:45/km.",
        "Para ajustar: recuperação depois do terceiro tiro em Z3 (148 bpm).",
    ]

    @Test func acceptsTextUsingOnlySourceNumbers() async {
        let text = "Bom treino: sete dos nove tiros no alvo, a 3:45/km. O trote depois do terceiro tiro ficou em Z3, com 148 bpm."
        #expect(await CoachFeedback.rewrite(facts: facts, generator: FixedFeedback(text: text)) == text)
    }

    @Test func rejectsInventedNumbersAndExclamations() async {
        #expect(await CoachFeedback.rewrite(facts: facts, generator: FixedFeedback(text: "Ótimo treino a 3:40/km.")) == nil)
        #expect(await CoachFeedback.rewrite(facts: facts, generator: FixedFeedback(text: "Ótimo treino!")) == nil)
    }

    @Test func rejectsPaceRewrittenAsHours() async {
        let paceFacts = ["Bloco de 12 km a 4:53/km, com a última volta em 4:59/km.", "Comece alguns segundos por km mais lento."]
        let hours = "O bloco de 12 km saiu em 4 horas e 53 minutos, e a última volta em 4 horas e 59 minutos."
        let split = "O bloco de 12 km saiu a 4 53 por km, e a última volta a 4:59/km."
        let right = "O bloco de 12 km saiu a 4:53/km e a última volta a 4:59/km. Comece alguns segundos por km mais lento."

        #expect(await CoachFeedback.rewrite(facts: paceFacts, generator: FixedFeedback(text: hours)) == nil)
        #expect(await CoachFeedback.rewrite(facts: paceFacts, generator: FixedFeedback(text: split)) == nil)
        #expect(await CoachFeedback.rewrite(facts: paceFacts, generator: FixedFeedback(text: right)) == right)
    }
}
