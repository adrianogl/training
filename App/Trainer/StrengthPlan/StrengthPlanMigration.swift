import Foundation
import Insights
import TrainingCore

enum StrengthPlanMigration {
    static func migrate(sessions: [TrainerStrengthSession], runningPlanEnd: Day?, today: Day, now: Date = .now) -> StrengthPlan? {
        let trainer = sessions.filter { $0.source == .trainer }
        guard !trainer.isEmpty else { return nil }
        let validity: StrengthPlanValidity
        if let runningPlanEnd, runningPlanEnd >= today {
            validity = .untilDate(runningPlanEnd)
        } else {
            validity = .weeks(Insights.StrengthPlanConstants.defaultWeeks)
        }
        let objective: StrengthObjective = trainer.allSatisfy { $0.group == .core } ? .mobility : .strength
        return StrengthPlan(
            objective: objective, sessions: trainer, start: today, validity: validity,
            builder: .trainer, createdAt: now, migrated: true
        )
    }
}
