import Foundation
import Insights
import MFIT
import TrainingCore

@MainActor
enum WorkoutSender {
    static func send(trainer: TrainerModel, today: Day) {
        let plans = plans(trainer: trainer, today: today)
        StrengthLiveStore().saveSentPlans(plans)
        guard let data = try? LiveStrengthWatch.message(plans) else { return }
        WatchLink.shared.sendPlans(data)
    }

    static func plans(trainer: TrainerModel, today: Day) -> [LiveStrengthPlan] {
        let cache = StrengthProgramStore().load()
        let records = cache.loads.map { LiveStrengthLoadHistory(key: $0.key, day: $0.day, loads: $0.loads) }
        return (0..<WatchLinkConstants.daysToSend).compactMap { offset in
            let day = today.adding(days: offset)
            return plan(for: day, trainer: trainer, cache: cache, history: LiveStrengthWatch.history(records, before: day.iso))
        }
    }

    private static func plan(
        for day: Day, trainer: TrainerModel, cache: StrengthProgramCache, history: [String: [LiveStrengthSetResult]]
    ) -> LiveStrengthPlan? {
        let mfit = trainer.replacesMFIT(on: day) ? nil : StrengthSchedule().workouts(cache.program, from: day, through: day).first
        if let mfit {
            let reader = LiveStrengthMFITReader(loadKey: MFITParser.exerciseKey, target: MFITParser.target)
            return LiveStrengthPlans.from(mfit: mfit, reader: reader, history: history)
        }
        guard let session = trainer.trainerSessions(on: day).first,
              let generated = trainer.strengthWorkout(sessionId: session.id, day: day, cache: cache) else { return nil }
        return LiveStrengthPlans.from(trainer: generated, day: day.iso, title: TrainerStrengthText.focusName(generated.group))
    }
}
