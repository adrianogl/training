import Sync
import SwiftData

enum ReprocessCommand {
    static func run(apiKey: String, container: ModelContainer, limit: Int?) async throws -> SyncReport {
        try await SyncCommand.engine(apiKey: apiKey, container: container).reprocess(limit: limit)
    }

    static func lines(_ report: SyncReport) -> [String] {
        [
            "FIT reprocessados: \(report.reprocessed)",
            "Parou no limite do Garmin (429): \(report.fitStoppedByRateLimit ? "sim" : "não")",
        ]
    }
}
