import Sync
import SwiftData

enum ReprocessCommand {
    static func run(apiKey: String, container: ModelContainer, limit: Int?) async throws -> SyncReport {
        try await SyncCommand.engine(apiKey: apiKey, container: container).reprocess(limit: limit)
    }

    static func lines(_ report: SyncReport) -> [String] {
        var lines = [
            "FIT reprocessados: \(report.reprocessed)",
            "Parou no limite do Garmin (429): \(report.fitStoppedByRateLimit ? "sim" : "não")",
        ]
        if !report.skippedFITs.isEmpty {
            lines.append("FIT pulados: \(report.skippedFITs.count)")
            lines += report.skippedFITs.prefix(CLIConstants.maxSkippedFITLines).map {
                "  atividade \($0.activityId): \($0.description)"
            }
        }
        return lines
    }
}
