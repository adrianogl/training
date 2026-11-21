import Foundation

extension TrainerModel {
    func checkStrengthPlanEnd(now: Date = .now) async {
        let store = strengthPlanStore
        let updated = await StrengthPlanEndNotifier.check(
            plan: strengthPlan, history: history, now: now, calendar: .current, scheduler: planEndScheduler,
            canNotify: canNotifyPlanEnd, save: { try store.save($0) }
        )
        if updated != nil { reloadStrengthPlan() }
    }
}
