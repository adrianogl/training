import Foundation
import Insights
import TrainingCore

extension TrainerModel {
    var mfitStrengthSessions: [TrainerStrengthSession] {
        legacyStrengthSessions.filter { $0.source == .mfit }
    }

    var isStrengthPlanEnded: Bool {
        strengthPlan.map { currentDay > $0.end } ?? false
    }

    func strengthPlanDone(_ plan: StrengthPlan) -> Int {
        plan.doneCount(doneDays: Set(history.strength.map(\.day)))
    }

    func strengthTargetRace() -> TrainerRaceOption? {
        let options = raceOptions()
        if let plan, plan.endedOn == nil, plan.target.kind == .race, let raceId = plan.target.raceId,
           let race = options.first(where: { $0.id == raceId }) {
            return race
        }
        return options.first
    }

    func resolvedStrengthPlan(_ plan: StrengthPlan) -> StrengthPlan {
        guard case .untilRace(let raceId, _) = plan.validity else { return plan }
        var resolved = plan
        if let race = raceOption(id: raceId) {
            resolved.validity = .untilRace(raceId: raceId, raceDay: race.day)
        } else {
            resolved.validity = .untilDate(plan.end)
        }
        return resolved
    }

    func repeatStrengthPlan() async {
        guard let strengthPlan else { return }
        await saveStrengthPlan(strengthPlan.repeated(after: currentDay))
    }

    func strengthDayCard(_ line: TrainerStrengthLine, day: Day) -> StrengthDayCardModel {
        guard line.source == .trainer, let workout = strengthWorkout(sessionId: line.id, day: day) else {
            return StrengthDayCardModel(
                source: line.source, isClaude: line.isClaude, minutes: nil, title: line.name, subtitle: nil,
                isDone: line.isDone, showsLink: line.source == .trainer
            )
        }
        return planDayCard(workout, day: day, isClaude: line.isClaude, isDone: line.isDone)
    }

    func planDayCard(_ workout: GeneratedStrengthWorkout, day: Day, isClaude: Bool, isDone: Bool) -> StrengthDayCardModel {
        let active = strengthPlan.flatMap { $0.isActive(on: day) ? $0 : nil }
        let week = isClaude ? nil : active?.week(on: day)
        return StrengthPlanDraftLogic.planDayCard(
            group: workout.group, minutes: workout.estimatedMinutes, exercises: workout.exercises.count, week: week,
            weeks: active?.totalWeeks ?? 0, note: workout.adjustments.first.map(TrainerStrengthText.adjustmentTitle),
            isClaude: isClaude, isDone: isDone
        )
    }
}
