import Foundation

extension TrainerModel {
    func checkStrengthPlanEnd(now: Date = .now) async {
        let previous = planEndCheck
        let task = Task { @MainActor [weak self] in
            await previous?.value
            await self?.runStrengthPlanEndCheck(now: now)
        }
        planEndCheck = task
        await task.value
    }

    private func runStrengthPlanEndCheck(now: Date) async {
        let store = strengthPlanStore
        let updated = await StrengthPlanEndNotifier.check(
            plan: store.current(), history: history, now: now, calendar: .current, scheduler: planEndScheduler,
            canNotify: canNotifyPlanEnd, save: { try store.save($0) }
        )
        if updated != nil { reloadStrengthPlan() }
    }
}
