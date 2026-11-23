import Foundation
import Insights
import MFIT
import TrainingCore

@MainActor
enum WorkoutSender {
    static func send(trainer: TrainerModel, today: Day) {
        let plans = plans(trainer: trainer, today: today)
        guard let data = try? LiveStrengthWatch.message(plans) else { return }
        let keepFrom = today.adding(days: -StrengthLiveConstants.plansKeptDays).iso
        WatchLink.shared.sendPlans(data) {
            StrengthLiveStore().rememberSentPlans(plans, keepFrom: keepFrom)
            StrengthLiveModel.shared.plansChanged()
        }
    }

    static func plans(trainer: TrainerModel, today: Day) -> [LiveStrengthPlan] {
        let cache = StrengthProgramStore().load()
        return (0..<WatchLinkConstants.daysToSend).compactMap { offset in
            plan(for: today.adding(days: offset), trainer: trainer, cache: cache)
        }
    }

    static func today(trainer: TrainerModel, day: Day) -> LiveStrengthPlan? {
        plan(for: day, trainer: trainer, cache: StrengthProgramStore().load())
    }

    static func isOnWatch(_ plan: LiveStrengthPlan) -> Bool {
        StrengthLiveStore().sentPlan(version: LiveStrengthWatch.version(plan)) != nil
    }

    static func resend(trainer: TrainerModel, today: Day) {
        WatchLink.shared.forgetSentPlans()
        send(trainer: trainer, today: today)
    }

    static func nextDay(of plan: LiveStrengthPlan, trainer: TrainerModel, after day: Day) -> Day? {
        let cache = StrengthProgramStore().load()
        return (1...StrengthLiveConstants.nextSearchDays).lazy.map { day.adding(days: $0) }.first { candidate in
            guard let next = Self.plan(for: candidate, trainer: trainer, cache: cache) else { return false }
            return next.source == plan.source && next.title == plan.title && (plan.sourceId == nil || next.sourceId == plan.sourceId)
        }
    }

    private static func plan(for day: Day, trainer: TrainerModel, cache: StrengthProgramCache) -> LiveStrengthPlan? {
        let records = cache.loads.map { LiveStrengthLoadHistory(key: $0.key, day: $0.day, loads: $0.loads) }
        let history = LiveStrengthWatch.history(records, before: day.iso)
        let suggested = StrengthLiveStore().nextLoads()
        let mfit = trainer.replacesMFIT(on: day) ? nil : StrengthSchedule().workouts(cache.program, from: day, through: day).first
        if let mfit {
            let reader = LiveStrengthMFITReader(loadKey: MFITParser.exerciseKey, target: MFITParser.target)
            return LiveStrengthPlans.from(mfit: mfit, reader: reader, history: history, suggested: suggested)
        }
        guard let session = trainer.trainerSessions(on: day).first,
              let generated = trainer.strengthWorkout(sessionId: session.id, day: day, cache: cache) else { return nil }
        return LiveStrengthPlans.from(
            trainer: generated, day: day.iso, title: TrainerStrengthText.focusName(generated.group),
            history: TrainerStrengthContextBuilder.lastSets(cache.loads, before: day.iso),
            suggested: suggested
        )
    }
}
