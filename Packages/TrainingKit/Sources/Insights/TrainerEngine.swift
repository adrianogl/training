import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

public enum TrainerEngine {
    public static let defaultStructure: [Int: TrainerDayKind] = C.defaultStructure

    public static func create(
        target: TrainerTarget, structure: [Int: TrainerDayKind], strength: [TrainerStrengthSession],
        history: TrainerHistory, today: Day, now: Date, startMeters: Double? = nil, peakMeters: Double? = nil,
        lightWeeks: [Day] = [], longMode: TrainerLongMode = .continuous
    ) -> TrainerPlan {
        let plan = build(
            target: target, structure: structure, strength: strength, history: history, today: today, offset: 0,
            startMeters: startMeters, peakMeters: peakMeters, lightWeeks: lightWeeks, longMode: longMode
        )
        let first = TrainerChange(
            kind: .skeleton, title: T.skeletonLabel, after: T.weeksLabel(plan.weeks.count), reason: T.createdSkeleton(weeks: plan.weeks.count)
        )
        var longChanges: [TrainerChange] = []
        if plan.longMode == .blocks {
            let meters = currentLongMeters(plan.weeks, today: today)
            let reason = T.longModeChanged(
                to: .blocks, stage: plan.longStage, blocks: longBlocks(stage: plan.longStage, meters: meters), rest: longRest(stage: plan.longStage)
            )
            longChanges = [TrainerChange(kind: .changed, title: T.longModeTitle, after: T.longModeSummary(.blocks, stage: plan.longStage, blocks: longBlocks(stage: plan.longStage, meters: meters), rest: longRest(stage: plan.longStage)), reason: reason)]
        }
        let weekChanges = newWeekChanges(oldEnd: nil, new: plan.workouts, weeks: plan.weeks)
        let version = TrainerVersion(
            number: 1, createdAt: now, trigger: .created,
            summary: T.createdSummary(
                weeks: plan.weeks.count, target: target.name, phases: T.phasesList(plan.weeks.map(\.phase)),
                goal: goalPaceSummary(target: target, paces: plan.paces)
            ),
            changes: [first] + longChanges + weekChanges
        )
        var result = plan
        result.versions = [version]
        return result
    }

    static func build(
        target: TrainerTarget, structure: [Int: TrainerDayKind], strength: [TrainerStrengthSession],
        history: TrainerHistory, today: Day, offset: Int, startMeters: Double?, peakMeters: Double?, lightWeeks: [Day] = [],
        longMode: TrainerLongMode = .continuous, longStage: Int? = nil
    ) -> TrainerPlan {
        let volume = startMeters ?? averageWeeklyMeters(history: history, today: today)
        let peak = max(volume, peakMeters ?? defaultPeak(from: volume))
        var paces = paces(history: history, today: today)
        paces.race = racePace(target)
        let datedWeeks = target.date.flatMap { date -> Int? in
            date >= today ? today.weekStart.days(until: date.weekStart) / C.daysPerWeek + 1 : nil
        }
        let context = skeletonContext(
            target: target, datedWeeks: datedWeeks.map { $0 + offset }, openTotal: offset + C.openHorizonWeeks,
            peakVolume: peak, lightWeeks: lightWeeks
        )
        let state = initialState(history: history, today: today, longCap: context.longCap, volume: volume)
        let weeks = buildWeeks(
            context: context, firstIndex: offset + 1, firstStart: today.weekStart, state: state, adjustment: TrainerSkeletonAdjustment()
        )
        var long = TrainerLongPlan(mode: longMode)
        if longMode == .blocks {
            long.stage = longStage ?? initialLongStage(
                history: history, plan: nil, today: today, meters: currentLongMeters(weeks, today: today)
            )
            long.evidence = longEvidence(history: history, plan: nil, today: today)
        }
        let workouts = detailWorkouts(
            weeks: weeks, structure: structure, paces: paces, history: history, target: target, today: today, past: [],
            requests: [], peakVolume: peak, long: long
        )
        return TrainerPlan(
            target: target, structure: structure, paces: paces,
            weeks: withPlannedMeters(weeks, workouts: workouts, structure: structure, target: target, history: history, today: today),
            workouts: workouts, versions: [], strength: strength, startMeters: startMeters, peakMeters: peakMeters,
            lightWeeks: lightWeeks, longMode: long.mode, longStage: long.stage
        )
    }
}
