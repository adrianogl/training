import Foundation
import Testing
@testable import trAIning

@Suite struct WorkoutChatTests {
    @Test func storeKeepsHistoryAndQuestionCountPerWorkout() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "chat-\(UUID().uuidString)")
        let store = WorkoutChatStore(folder: folder)
        let messages = [
            ChatMessage(role: .user, text: "Meu trote foi rápido demais?"),
            ChatMessage(role: .assistant, text: "Sim, nas recuperações 3 e 4.", toolNote: "leu os blocos"),
            ChatMessage(role: .user, text: "E no fim?"),
        ]

        await store.save(messages, for: 42)

        let reloaded = WorkoutChatStore(folder: folder)
        #expect(await reloaded.messages(for: 42) == messages)
        #expect(await reloaded.questionCounts() == [42: 2])
        #expect(await reloaded.messages(for: 7).isEmpty)
    }

    @Test func numbersMustComeFromFactsOrTools() {
        let source = "Tiro 4: pace 3:45/km, FC 160 bpm. Recuperação 3: FC 148 bpm."
        #expect(WorkoutChatEngine.numbersMatch("O quarto tiro saiu a 3:45/km depois de um trote a 148 bpm.", source: source))
        #expect(!WorkoutChatEngine.numbersMatch("O quarto tiro saiu a 3:52/km.", source: source))
    }
}
