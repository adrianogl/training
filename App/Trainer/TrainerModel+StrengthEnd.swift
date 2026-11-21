import Foundation

extension TrainerModel {
    func checkStrengthPlanEnd(now: Date = .now) async {
        let updated = await StrengthPlanEndNotifier.check(
            plan: strengthPlan, history: history, now: now, calendar: .current, scheduler: planEndScheduler
        )
        guard let updated else { return }
        try? strengthPlanStore.save(updated)
        reloadStrengthPlan()
    }
}
