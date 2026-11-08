import GarminAPI
import Sync
import SwiftData
import TrainingCore

struct SyncEngineConfiguration: Equatable {
    let fitLimit: Int?

    init(trigger: SyncTrigger) {
        switch trigger {
        case .launch: fitLimit = AppConstants.launchFITLimit
        case .settings: fitLimit = nil
        }
    }

    func makeEngine(source: any GarminDataSource, container: ModelContainer) -> SyncEngine {
        SyncEngine(source: source, container: container, today: { Day.today() }, fitLimit: fitLimit)
    }
}
