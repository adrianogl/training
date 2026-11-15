import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

public enum TrainerEngine {
    public static let defaultStructure: [Int: TrainerDayKind] = C.defaultStructure

    public static func create(
        target: TrainerTarget, structure: [Int: TrainerDayKind], strength: [TrainerStrengthSession],
        history: TrainerHistory, today: Day, now: Date, weeklyMeters: Double? = nil
    ) -> TrainerPlan {
        let plan = build(
            target: target, structure: structure, strength: strength, history: history, today: today, offset: 0, weeklyMeters: weeklyMeters
        )
        let first = TrainerChange(
            kind: .skeleton, title: T.skeletonLabel, after: T.weeksLabel(plan.weeks.count), reason: T.createdSkeleton(weeks: plan.weeks.count)
        )
        let weekChanges = newWeekChanges(oldEnd: nil, new: plan.workouts, weeks: plan.weeks)
        let version = TrainerVersion(
            number: 1, createdAt: now, trigger: .created,
            summary: T.createdSummary(
                weeks: plan.weeks.count, target: target.name, phases: T.phasesList(plan.weeks.map(\.phase))
            ),
            changes: [first] + weekChanges
        )
        var result = plan
        result.versions = [version]
        return result
    }

    static func build(
        target: TrainerTarget, structure: [Int: TrainerDayKind], strength: [TrainerStrengthSession],
        history: TrainerHistory, today: Day, offset: Int, weeklyMeters: Double?
    ) -> TrainerPlan {
        let volume = weeklyMeters ?? averageWeeklyMeters(history: history, today: today)
        var paces = paces(history: history, today: today)
        paces.race = racePace(target)
        let datedWeeks = target.date.flatMap { date -> Int? in
            date >= today ? today.weekStart.days(until: date.weekStart) / C.daysPerWeek + 1 : nil
        }
        let context = skeletonContext(
            target: target, datedWeeks: datedWeeks.map { $0 + offset }, openTotal: offset + C.openHorizonWeeks,
            baseVolume: volume
        )
        let state = initialState(history: history, today: today, longCap: context.longCap, volume: volume)
        let weeks = buildWeeks(
            context: context, firstIndex: offset + 1, firstStart: today.weekStart, state: state, adjustment: TrainerSkeletonAdjustment()
        )
        let workouts = detailWorkouts(
            weeks: weeks, structure: structure, paces: paces, history: history, target: target, today: today, past: [],
            requests: [], strength: strength
        )
        return TrainerPlan(
            target: target, structure: structure, paces: paces,
            weeks: withPlannedMeters(weeks, workouts: workouts, structure: structure, target: target, history: history, today: today),
            workouts: workouts, versions: [], strength: strength, weeklyMeters: weeklyMeters
        )
    }
}
