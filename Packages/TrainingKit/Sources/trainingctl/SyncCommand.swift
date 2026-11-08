import Foundation
import GarminAPI
import Synchronization
import Sync
import SwiftData
import TrainingCore

enum SyncCommand {
    static func keyPath() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: CLIConstants.keyRelativePath)
    }

    static func readKey(at url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CLIError.missingKey(path: url.path)
        }
        let key = try String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw CLIError.emptyKey(path: url.path) }
        return key
    }

    static func run(apiKey: String, container: ModelContainer) async throws -> SyncReport {
        let transport = URLSessionTransport()
        let tokens = TokenProvider(apiKey: apiKey, baseURL: GarminEndpoints.base, transport: transport)
        let client = GarminClient(tokens: tokens, transport: transport)
        let engine = SyncEngine(source: client, container: container, today: { Day.today() })
        let lastPercent = Mutex(-1)
        return try await engine.run { fraction in
            let percent = Int((fraction * 100).rounded(.down))
            let changed = lastPercent.withLock { last in
                guard percent > last else { return false }
                last = percent
                return true
            }
            if changed { print("Progresso: \(percent)%") }
        }
    }

    static func lines(_ report: SyncReport) -> [String] {
        [
            "Dias gravados: \(report.dailyUpserted)",
            "Atividades gravadas: \(report.activitiesUpserted)",
            "FIT processados: \(report.fitProcessed)",
            "Duplicatas removidas: \(report.duplicatesRemoved)",
        ]
    }
}
