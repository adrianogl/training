import Foundation

struct ClaudeContextEnvelope: Codable, Equatable {
    let atualizado: String
    let texto: String
    let contexto: ClaudeContextPayload
}

struct ClaudeOutbox: Codable, Equatable {
    let data: Data
    let stamp: Date
    let signature: String
}

struct ClaudeInbox: Codable, Equatable {
    let json: String
    let savedAt: Date
}

struct ClaudeInboxEnvelope: Decodable {
    let salvoEm: String
    let json: String
}
