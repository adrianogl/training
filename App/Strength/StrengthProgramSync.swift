import Foundation
import MFIT
import TrainingCore

@MainActor enum StrengthProgramSync {
    static var changed: (@MainActor (MFITProgramUpdate) async -> Void)?

    @discardableResult
    static func refresh(client: MFITClient, today: Day, store: StrengthProgramStore = StrengthProgramStore(), notifies: Bool = true) async throws -> MFITProgramUpdate {
        guard let fetched = try await client.currentProgram(today: today.iso) else {
            return MFITProgramUpdate(cache: store.clearProgram(), changes: [])
        }
        let update = store.refresh(with: fetched)
        if notifies, !update.changes.isEmpty, let changed { Task { @MainActor in await changed(update) } }
        return update
    }
}
