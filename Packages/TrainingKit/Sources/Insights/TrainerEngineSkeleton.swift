import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    static func roundKilometers(_ meters: Double) -> Double {
        (meters / C.metersPerKilometer).rounded() * C.metersPerKilometer
    }

    public static func defaultPeak(from start: Double) -> Double {
        roundKilometers(start * C.defaultPeakShare)
    }

    public static func weeksToPeak(startMeters: Double, peakMeters: Double) -> Int {
        let context = TrainerSkeletonContext(
            total: C.weeksToPeakLimit, taperWeeks: 0, openEnded: true, longCap: C.fallbackLongCap, peakVolume: peakMeters
        )
        let state = TrainerSkeletonState(volume: startMeters, long: 0, stage: 0, weeksAtStage: 0, started: false)
        let weeks = buildWeeks(context: context, firstIndex: 1, firstStart: Day(year: 2000, month: 1, day: 3), state: state, adjustment: TrainerSkeletonAdjustment())
        return weeks.first { $0.targetMeters >= peakMeters && !$0.isRecovery }?.index ?? C.weeksToPeakLimit
    }

    static func roundHalfKilometers(_ meters: Double) -> Double {
        (meters / C.halfKilometer).rounded() * C.halfKilometer
    }

    static func longCap(for target: TrainerTarget) -> Double {
        guard let meters = target.distanceMeters else { return C.fallbackLongCap }
        return C.longCaps.first { meters <= $0.upTo }?.cap ?? C.fallbackLongCap
    }

    static func skeletonContext(
        target: TrainerTarget, datedWeeks: Int?, openTotal: Int, peakVolume: Double, lightWeeks: [Day] = [],
        earlyLightWeeks: [Day: TrainerLightKind] = [:]
    ) -> TrainerSkeletonContext {
        let cap = longCap(for: target)
        guard let datedWeeks else {
            return TrainerSkeletonContext(
                total: openTotal, taperWeeks: 0, openEnded: true, longCap: cap, peakVolume: peakVolume, lightWeeks: lightWeeks,
                earlyLightWeeks: earlyLightWeeks
            )
        }
        let taper = (target.distanceMeters ?? .infinity) <= C.shortRaceMeters ? C.shortRaceTaperWeeks : C.taperWeeks
        return TrainerSkeletonContext(
            total: datedWeeks, taperWeeks: min(taper, datedWeeks), openEnded: false, longCap: cap, peakVolume: peakVolume,
            lightWeeks: lightWeeks, earlyLightWeeks: earlyLightWeeks, generalWeeks: max(0, datedWeeks - blockWeeks(for: target))
        )
    }

    static func blockWeeks(for target: TrainerTarget) -> Int {
        let meters = target.distanceMeters ?? 0
        return C.blockWeeksLimits.first { meters >= $0.from }?.weeks ?? C.defaultBlockWeeks
    }

    static func phase(of index: Int, in context: TrainerSkeletonContext) -> TrainerPhase {
        if index <= context.generalWeeks { return .general }
        let span = context.openEnded ? C.openHorizonWeeks : context.total - context.taperWeeks - context.generalWeeks
        if !context.openEnded && index > span + context.generalWeeks { return .taper }
        let position = context.openEnded ? (index - 1) % C.openHorizonWeeks + 1 : index - context.generalWeeks
        let base = Int((C.baseShare * Double(span)).rounded())
        let build = Int((C.buildShare * Double(span)).rounded())
        if position <= base { return .base }
        if position <= base + build { return .build }
        return .specific
    }

    public static func averageWeeklyMeters(history: TrainerHistory, today: Day) -> Double {
        let weekly = history.runs
            .filter { $0.day >= today.weekStart.adding(days: -C.volumeWindowDays) && $0.day < today.weekStart }
            .reduce(0.0) { $0 + $1.meters } / C.volumeWindowWeeks
        return weekly > 0 ? roundKilometers(weekly) : C.fallbackWeeklyMeters
    }

    static func initialState(history: TrainerHistory, today: Day, longCap: Double, volume: Double) -> TrainerSkeletonState {
        let longest = history.runs
            .filter { $0.kind == .long && $0.day > today.adding(days: -C.longWindowDays) && $0.day <= today }
            .map(\.meters).max() ?? 0
        let long = min(roundKilometers(max(longest, C.minimumLongMeters)), longCap)
        return TrainerSkeletonState(volume: volume, long: long, stage: 0, weeksAtStage: 0, started: false)
    }

    static func derivedState(from weeks: [TrainerWeek]) -> TrainerSkeletonState? {
        let progression = weeks.filter { !$0.isRecovery && $0.phase != .taper && $0.phase != .general }
        guard let last = progression.last else { return nil }
        let stage = stageIndex(of: last.thresholdFocus)
        var level = 0
        for week in progression.reversed() where stageIndex(of: week.thresholdFocus) == stage {
            level += 1
        }
        return TrainerSkeletonState(
            volume: last.targetMeters, long: last.baseLongMeters ?? last.longMeters, stage: stage,
            weeksAtStage: min(level, C.stagesAtLevel), started: true, returning: weeks.last?.isRecovery == true,
            lastRecovery: weeks.last { $0.isRecovery }?.index
        )
    }

    static func stageIndex(of label: String) -> Int {
        C.thresholdBlocks.firstIndex { TrainerEngineText.stageLabel($0) == label } ?? 0
    }

    static func nextVolume(state: TrainerSkeletonState, phase: TrainerPhase, context: TrainerSkeletonContext) -> Double {
        if state.returning { return state.volume }
        let cap = context.openEnded || phase == .specific
            ? context.peakVolume
            : max(roundKilometers(context.peakVolume * C.preSpecificPeakShare), state.volume)
        let grown = max(roundKilometers(state.volume * (1 + C.weeklyGrowth)), state.volume + C.metersPerKilometer)
        return min(grown, max(cap, state.volume))
    }

    static func buildWeeks(
        context: TrainerSkeletonContext, firstIndex: Int, firstStart: Day,
        state initial: TrainerSkeletonState, adjustment: TrainerSkeletonAdjustment
    ) -> [TrainerWeek] {
        guard firstIndex <= context.total else { return [] }
        var state = initial
        var holdPending = adjustment.holdProgression
        var weeks: [TrainerWeek] = []
        var lastRecovery = initial.lastRecovery ?? (firstIndex - 1) / C.recoveryEvery * C.recoveryEvery
        for index in firstIndex...context.total {
            let first = index == firstIndex
            let phase = phase(of: index, in: context)
            let start = firstStart.adding(days: (index - firstIndex) * C.daysPerWeek)
            let early = phase == .taper ? nil : context.earlyLightWeeks[start]
            let recovery = phase != .taper && (context.lightWeeks.contains(start) || early != nil || index - lastRecovery >= C.recoveryEvery)
            if recovery { lastRecovery = index }
            var volume: Double
            var long: Double
            var stage: Int
            if phase == .taper {
                let position = max(0, index - (context.total - context.taperWeeks) - 1)
                let share = C.taperShares[min(position, C.taperShares.count - 1)]
                volume = roundKilometers(context.peakVolume * share)
                long = roundKilometers(state.long * share)
                stage = max(0, state.stage - 1)
            } else if recovery {
                volume = roundKilometers(state.volume * lightVolumeShare(early))
                state.returning = true
                long = roundKilometers(state.long * C.recoveryLongShare)
                stage = max(0, state.stage - 1)
            } else if phase == .general {
                if first, let scale = adjustment.volumeScale { state.volume = roundKilometers(state.volume * scale) }
                if first, let cap = adjustment.longCap { state.long = min(state.long, cap) }
                state.returning = false
                holdPending = false
                volume = state.volume
                long = state.long
                stage = 0
            } else {
                if !state.started {
                    state.started = true
                    state.weeksAtStage = 1
                } else if first, let scale = adjustment.volumeScale {
                    state.volume = roundKilometers(state.volume * scale)
                    state.weeksAtStage = min(C.stagesAtLevel, state.weeksAtStage + 1)
                    holdPending = false
                    state.returning = false
                } else if holdPending {
                    state.returning = false
                    state.weeksAtStage = min(C.stagesAtLevel, state.weeksAtStage + 1)
                    holdPending = false
                } else {
                    state.volume = nextVolume(state: state, phase: phase, context: context)
                    state.returning = false
                    state.long = min(state.long + C.longStep, context.longCap)
                    if context.openEnded && index % C.recoveryEvery == 1 && state.stage == C.thresholdBlocks.count - 1 {
                        state.stage = 0
                        state.weeksAtStage = 1
                    } else if state.weeksAtStage >= C.stagesAtLevel {
                        state.stage = min(state.stage + 1, C.thresholdBlocks.count - 1)
                        state.weeksAtStage = 1
                    } else {
                        state.weeksAtStage += 1
                    }
                }
                if first, let cap = adjustment.longCap { state.long = min(state.long, cap) }
                volume = state.volume
                long = state.long
                stage = state.stage
            }
            if first && (phase == .taper || recovery) {
                if early == nil, let scale = adjustment.volumeScale { volume = roundKilometers(volume * scale) }
                if let cap = adjustment.longCap { long = min(long, cap) }
            }
            weeks.append(TrainerWeek(
                index: index, start: start, phase: phase,
                isRecovery: recovery, plannedMeters: volume, targetMeters: volume, longMeters: long,
                thresholdFocus: TrainerEngineText.stageLabel(C.thresholdBlocks[stage]), vo2Focus: "", lightKind: early
            ))
        }
        return weeks
    }
}
