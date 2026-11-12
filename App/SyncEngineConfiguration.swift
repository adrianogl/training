import Foundation
import GarminAPI
import Sync
import SwiftData
import TrainingCore

struct SyncEngineConfiguration: Equatable {
    let fitLimit: Int?
    let mode: SyncMode
    let waitsOnRateLimit: Bool

    init(trigger: SyncTrigger, hasOutdatedRuns: Bool = false) {
        switch trigger {
        case .launch:
            fitLimit = AppConstants.launchFITLimit
            mode = .foreground
        case .pull:
            fitLimit = hasOutdatedRuns ? nil : AppConstants.launchFITLimit
            mode = .foreground
        case .settings:
            fitLimit = nil
            mode = .foreground
        case .background:
            fitLimit = nil
            mode = .background
        }
        waitsOnRateLimit = mode == .foreground
    }

    static func hasOutdatedRuns(container: ModelContainer) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            (try? Sync.hasOutdatedRuns(in: ModelContext(container))) == true
        }.value
    }

    func makeClient(tokens: TokenProvider, transport: any HTTPTransport) -> GarminClient {
        GarminClient(tokens: tokens, transport: transport, waitsOnRateLimit: waitsOnRateLimit)
    }

    func makeEngine(source: any GarminDataSource, container: ModelContainer) -> SyncEngine {
        SyncEngine(source: source, container: container, today: { Day.today() }, fitLimit: fitLimit, mode: mode)
    }
}
