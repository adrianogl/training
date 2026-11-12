import FITReader
import Foundation
import GarminAPI
import Storage
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

    static func hasOutdatedRuns(in context: ModelContext) throws -> Bool {
        let currentVersion = FITReaderConstants.processingVersion
        var descriptor = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.fitProcessed && $0.processingVersion < currentVersion }
        )
        descriptor.propertiesToFetch = [\.typeKey]
        return try context.fetch(descriptor).contains { ActivityTypeKey.isRun($0.typeKey) }
    }

    func makeClient(tokens: TokenProvider, transport: any HTTPTransport) -> GarminClient {
        GarminClient(tokens: tokens, transport: transport, waitsOnRateLimit: waitsOnRateLimit)
    }

    func makeEngine(source: any GarminDataSource, container: ModelContainer) -> SyncEngine {
        SyncEngine(source: source, container: container, today: { Day.today() }, fitLimit: fitLimit, mode: mode)
    }
}
