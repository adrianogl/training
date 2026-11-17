import SwiftUI

enum ClaudeConstants {
    static let storeKey = "claudeStrengthWorkouts"
    static let color = Color(hex: 0xD97757)
    static let symbol = "sparkles"
    static let readinessDays = 7
    static let fallbackWeeks = 12
    static let contextBlobId = "strengthContext"
    static let inboxBlobId = "strengthClaude"
    static let outboxKey = "claudeContextOutbox"
    static let contextSyncedKey = "claudeContextSynced"
    static let inboxKey = "claudeInbox"
    static let inboxSeenKey = "claudeInboxSeen"
    static let mcpTokenCreatedKey = "claudeMcpTokenCreated"
    static let overrideIdPrefix = "00000000-0000-4000-9000-0000"
    static let mcpURL = "https://training.aglv.dev/mcp"
}
