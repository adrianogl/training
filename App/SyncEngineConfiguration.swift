import GarminAPI
import Sync
import SwiftData
import TrainingCore

struct SyncEngineConfiguration: Equatable {
    let fitLimit: Int?
    let mode: SyncMode
    let waitsOnRateLimit: Bool

    init(trigger: SyncTrigger) {
        switch trigger {
        case .launch:
            fitLimit = AppConstants.launchFITLimit
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

    func makeClient(tokens: TokenProvider, transport: any HTTPTransport) -> GarminClient {
        GarminClient(tokens: tokens, transport: transport, waitsOnRateLimit: waitsOnRateLimit)
    }

    func makeEngine(source: any GarminDataSource, container: ModelContainer) -> SyncEngine {
        SyncEngine(source: source, container: container, today: { Day.today() }, fitLimit: fitLimit, mode: mode)
    }
}
