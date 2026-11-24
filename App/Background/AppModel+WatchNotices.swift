import Foundation
import MFIT
import TrainingCore

extension AppModel {
    func installWatchNoticeHandlers() {
        WatchPendingNotifier.registerCategory()
        trainer.hasGarminAccount = { [weak self] in self?.garminAccount.isSignedIn ?? false }
        garminAccount.signedInChanged = { [weak self] in self?.trainer.scheduleNoticeRefresh() }
        WatchPendingActionHandler.shared.send = { [weak self] in await self?.sendPendingToGarmin() }
        StrengthProgramSync.changed = { [weak self] update in await self?.notifyMFITChanges(update) }
    }

    func sendPendingToGarmin() async {
        guard watchKind == .garmin, let client = garminAccount.client else { return }
        await trainer.sendPendingToGarmin(client: client)
    }

    func backgroundSend() async {
        await backgroundSend(mfit: await refreshMFITInBackground())
    }

    func backgroundSend(mfit update: MFITProgramUpdate?) async {
        let changed = update.flatMap { $0.changes.isEmpty ? nil : $0 }
        let teacher = await teacherName(changed?.cache.program?.teacherId)
        if let changed { await scheduleMFITChange(changed, teacher: teacher, afterAutoSend: false, onlyPending: false) }
        guard !Task.isCancelled else { return }
        if watchKind == .garmin { await trainer.autoSend(client: garminAccount.client) }
        guard !Task.isCancelled else { return }
        await trainer.refreshChangeWatch()
        if let changed { await scheduleMFITChange(changed, teacher: teacher, afterAutoSend: true, onlyPending: true) }
        await trainer.checkWatchPending()
    }

    func notifyMFITChanges(_ update: MFITProgramUpdate) async {
        guard update.cache.program != nil, !update.changes.isEmpty else { return }
        let teacher = await teacherName(update.cache.program?.teacherId)
        await scheduleMFITChange(update, teacher: teacher, afterAutoSend: false, onlyPending: false)
        await trainer.checkWatchPending()
    }

    private func scheduleMFITChange(_ update: MFITProgramUpdate, teacher: String?, afterAutoSend: Bool, onlyPending: Bool) async {
        guard let program = update.cache.program else { return }
        let watch = mfitWatch(update.changes, afterAutoSend: afterAutoSend)
        await mfitChanges.notify(update.changes, program: program, teacher: teacher, watch: watch, onlyPending: onlyPending)
    }

    private func refreshMFITInBackground() async -> MFITProgramUpdate? {
        guard let client = mfitAccount.client else { return nil }
        return try? await StrengthProgramSync.refresh(client: client, today: trainer.currentDay, notifies: false)
    }

    private func teacherName(_ id: Int64?) async -> String? {
        guard let id, let client = mfitAccount.client else { return nil }
        return try? await client.teachers().first { $0.id == id }?.name
    }

    private func mfitWatch(_ changes: [MFITProgramChange], afterAutoSend: Bool) -> TrainerChangeWatch {
        let store = TrainerSendStore(defaults: trainer.defaults)
        let settings = store.settings()
        guard trainer.sendsToGarmin, settings.sendsMFIT else { return .none }
        let suffixes = changes.filter { $0.kind != .removed }.map { "|" + String($0.workout.id) }
        let items = trainer.sendItems(.strength, settings: settings).filter { item in item.isMFIT && suffixes.contains { item.key.hasSuffix($0) } }
        guard !items.isEmpty else { return .none }
        let records = store.records()
        if items.allSatisfy({ TrainerSendBuilder.status($0, records: records) == .current }) { return .current }
        return !afterAutoSend && settings.auto?.kinds.contains(.strength) == true ? .none : .pending
    }
}
