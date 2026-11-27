import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

public enum TrainerEngine {
    public static let defaultStructure: [Int: TrainerDayKind] = C.defaultStructure

    public static func create(
        target: TrainerTarget, structure: [Int: TrainerDayKind], strength: [TrainerStrengthSession],
        history: TrainerHistory, today: Day, now: Date, startMeters: Double? = nil, peakMeters: Double? = nil,
        lightWeeks: [Day] = [], longMode: TrainerLongMode = .continuous, dayPreference: TrainerDayPreference? = nil,
        paceOverrides: [TrainerPaceKind: Double] = [:], outAndBack: Bool = false
    ) -> TrainerPlan {
        var plan = build(
            target: target, structure: structure, strength: strength, history: history, today: today, offset: 0,
            startMeters: startMeters, peakMeters: peakMeters, lightWeeks: lightWeeks, longMode: longMode, paceOverrides: paceOverrides,
            outAndBack: outAndBack
        )
        if let dayPreference { plan.dayPreference = dayPreference }
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
                goal: goalPaceSummary(target: target, paces: plan.paces),
                blockStart: plan.weeks.contains { $0.phase == .general } ? plan.weeks.first { $0.phase != .general }?.start : nil
            ),
            changes: [first] + longChanges + weekChanges
        )
        var result = plan
        result.versions = [version]
        result.rulesVersion = C.prescriptionRulesVersion
        return result
    }

    static func build(
        target: TrainerTarget, structure: [Int: TrainerDayKind], strength: [TrainerStrengthSession],
        history: TrainerHistory, today: Day, offset: Int, startMeters: Double?, peakMeters: Double?, lightWeeks: [Day] = [],
        longMode: TrainerLongMode = .continuous, longStage: Int? = nil, paceOverrides: [TrainerPaceKind: Double] = [:],
        earlyLightWeeks: [Day: TrainerLightKind] = [:], calmWeeks: [Day] = [], lastRecovery: Int? = nil, outAndBack: Bool = false
    ) -> TrainerPlan {
        let volume = startMeters ?? averageWeeklyMeters(history: history, today: today)
        let peak = max(volume, peakMeters ?? defaultPeak(from: volume))
        let paces = resolvedPaces(history: history, today: today, target: target, overrides: paceOverrides)
        let datedWeeks = target.date.flatMap { date -> Int? in
            date >= today ? today.weekStart.days(until: date.weekStart) / C.daysPerWeek + 1 : nil
        }
        let context = skeletonContext(
            target: target, datedWeeks: datedWeeks.map { $0 + offset }, openTotal: offset + C.openHorizonWeeks,
            peakVolume: peak, paces: paces, lightWeeks: lightWeeks, earlyLightWeeks: earlyLightWeeks, calmWeeks: calmWeeks,
            outAndBack: outAndBack
        )
        var state = initialState(history: history, today: today, longCap: context.longCap(at: volume), volume: volume)
        state.lastRecovery = lastRecovery
        let sized = sizedWeeks(buildWeeks(
            context: context, firstIndex: offset + 1, firstStart: today.weekStart, state: state, adjustment: TrainerSkeletonAdjustment()
        ), paces: paces)
        let weeks = labeledVo2(evenLongs(longestLongs(
            wavedLongs(sized, from: offset + 1, structure: structure, target: target, paces: paces, mode: longMode),
            structure: structure, target: target, history: history, today: today, paces: paces
        ), paces: paces), from: offset + 1)
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
            weeks: withPlannedMeters(weeks, workouts: workouts, structure: structure, target: target, history: history, today: today, paces: paces),
            workouts: workouts, versions: [], strength: strength, startMeters: startMeters, peakMeters: peakMeters,
            lightWeeks: lightWeeks, earlyLightWeeks: earlyLightWeeks, calmWeeks: calmWeeks, longMode: long.mode, longStage: long.stage, paceOverrides: paceOverrides,
            outAndBack: outAndBack
        )
    }
}
