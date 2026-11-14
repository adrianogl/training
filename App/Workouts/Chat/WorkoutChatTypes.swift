import Foundation

enum ChatRole: String, Codable, Sendable {
    case user, assistant
}

struct ChatMessage: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let role: ChatRole
    let text: String
    let date: Date
    var toolNote: String?
    var unverified = false

    init(role: ChatRole, text: String, date: Date = .now, toolNote: String? = nil, unverified: Bool = false) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.date = date
        self.toolNote = toolNote
        self.unverified = unverified
    }
}

struct WorkoutChatCopy: Sendable {
    let instructions: String
    let factsHeader: String
    let historyHeader: String
    let welcome: String
    let placeholder: String
    let blocksDescription: String
    let similarDescription: String
    let dayDescription: String
    let blocksNote: String
    let dayNote: String
}

struct WorkoutChatContext: Sendable {
    var copy = WorkoutChatConstants.doneCopy
    let title: String
    let facts: String
    let blockLines: [String]
    let similarLines: [String]
    let dayLine: String?
    let suggestions: [String]
}
