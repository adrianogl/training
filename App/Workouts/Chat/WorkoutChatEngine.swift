import Foundation
import FoundationModels

actor ChatToolLog {
    private(set) var notes: [String] = []
    private(set) var outputs: [String] = []

    func record(_ note: String, output: String) {
        if !notes.contains(note) { notes.append(note) }
        outputs.append(output)
    }

    func drain() -> (notes: [String], outputs: [String]) {
        defer { notes = []; outputs = [] }
        return (notes, outputs)
    }
}

struct BlocksTool: Tool {
    let name = "blocos_do_treino"
    let description: String
    let note: String
    let lines: [String]
    let log: ChatToolLog

    @Generable
    struct Arguments {
        @Guide(description: "Número do primeiro bloco, começando em 1. Use 1 para todos.")
        var first: Int
        @Guide(description: "Número do último bloco. Use 0 para ir até o fim.")
        var last: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let lower = max(arguments.first, 1) - 1
        let upper = arguments.last <= 0 ? lines.count : min(arguments.last, lines.count)
        let text = lower < upper ? lines[lower..<upper].joined(separator: "\n") : lines.joined(separator: "\n")
        await log.record(note, output: text)
        return text
    }
}

struct SimilarRunsTool: Tool {
    let name = "treinos_parecidos"
    let description: String
    let lines: [String]
    let log: ChatToolLog

    @Generable
    struct Arguments {
        @Guide(description: "Quantos treinos devolver, do mais recente para o mais antigo.")
        var count: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let text = lines.prefix(max(arguments.count, 1)).joined(separator: "\n")
        let output = text.isEmpty ? "Sem treinos parecidos." : text
        await log.record(WorkoutChatConstants.toolSimilar, output: output)
        return output
    }
}

struct DayTool: Tool {
    let name = "dados_do_dia"
    let description: String
    let note: String
    let line: String?
    let log: ChatToolLog

    @Generable
    struct Arguments {
        @Guide(description: "Sempre true.")
        var include: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        let output = line ?? "Sem dados de recuperação para esse dia."
        await log.record(note, output: output)
        return output
    }
}

actor WorkoutChatEngine {
    private typealias C = WorkoutChatConstants

    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    private let context: WorkoutChatContext
    private let log = ChatToolLog()
    private let session: LanguageModelSession

    init(context: WorkoutChatContext, history: [ChatMessage]) {
        self.context = context
        let previous = history.suffix(C.historyLimit).map { "\($0.role == .user ? "Atleta" : "Treinador"): \($0.text)" }.joined(separator: "\n")
        let copy = context.copy
        var instructions = copy.instructions + "\n\n" + copy.factsHeader + "\n" + context.facts
        if !previous.isEmpty { instructions += "\n\n" + copy.historyHeader + "\n" + previous }
        session = LanguageModelSession(
            tools: [
                BlocksTool(description: copy.blocksDescription, note: copy.blocksNote, lines: context.blockLines, log: log),
                SimilarRunsTool(description: copy.similarDescription, lines: context.similarLines, log: log),
                DayTool(description: copy.dayDescription, note: copy.dayNote, line: context.dayLine, log: log),
            ],
            instructions: instructions
        )
    }

    func answer(_ question: String) async -> ChatMessage {
        guard let response = try? await session.respond(to: question) else {
            return ChatMessage(role: .assistant, text: C.failed)
        }
        let (notes, outputs) = await log.drain()
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = ([context.facts, question] + outputs).joined(separator: "\n")
        return ChatMessage(
            role: .assistant,
            text: text,
            toolNote: notes.isEmpty ? nil : notes.joined(separator: " · "),
            unverified: !Self.numbersMatch(text, source: source)
        )
    }

    static func numbersMatch(_ text: String, source: String) -> Bool {
        let numbers = { (value: String) in Set(value.matches(of: /\d+/).map { String($0.output) }) }
        return numbers(text).isSubset(of: numbers(source))
    }
}
