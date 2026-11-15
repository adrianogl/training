import Foundation
import Metrics
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerPlan {
    var longPlan: TrainerLongPlan {
        TrainerLongPlan(mode: longMode, stage: longStage, streak: longStageStreak, misses: longStageMisses)
    }

    mutating func apply(_ long: TrainerLongPlan) {
        longMode = long.mode
        longStage = long.stage
        longStageStreak = long.streak
        longStageMisses = long.misses
    }
}

extension TrainerEngine {
    public static let longStageCount = C.longStageCount
    public static let longStageAdvanceStreak = C.longStageAdvanceStreak

    public static func longBlocks(stage: Int, meters: Double) -> [Double] {
        let shares = C.longStageShares[min(max(stage, 1), C.longStageCount) - 1]
        var blocks: [Double] = []
        var used = 0.0
        for share in shares {
            let size = max(roundHalfKilometers(meters * share), C.halfKilometer)
            guard used + size < meters else { break }
            blocks.append(size)
            used += size
        }
        blocks.append(meters - used)
        return blocks
    }

    public static func longRest(stage: Int) -> Double? {
        stage >= 1 && stage <= C.longStageRests.count ? C.longStageRests[stage - 1] : nil
    }

    public static func plannedPauses(of workout: TrainerWorkout) -> Int {
        workout.kind == .long ? workout.steps.filter { $0.kind == .recovery && $0.restSeconds != nil }.reduce(0) { $0 + $1.repeats } : 0
    }

    static func longBlockSteps(blocks: [Double], rest: Double, longPace: Double) -> [TrainerStep] {
        let opening = band(longPace + C.longBlockOpenOffset, C.easyBand)
        let main = band(longPace, C.easyBand)
        var steps: [TrainerStep] = []
        for (index, size) in blocks.enumerated() {
            let head = min(size, C.longBlockOpenMeters)
            steps.append(TrainerStep(kind: .steady, meters: head, paceLow: opening.low, paceHigh: opening.high))
            if size > head {
                steps.append(TrainerStep(kind: .steady, meters: size - head, paceLow: main.low, paceHigh: main.high))
            }
            if index < blocks.count - 1 { steps.append(TrainerStep(kind: .recovery, meters: 0, restSeconds: rest)) }
        }
        return steps
    }

    static func blockSizes(of workout: TrainerWorkout) -> [Double] {
        var sizes: [Double] = []
        var current = 0.0
        for step in workout.steps {
            if step.kind == .recovery, step.restSeconds != nil {
                sizes.append(current)
                current = 0
            } else {
                current += step.meters * Double(step.repeats)
            }
        }
        return sizes + [current]
    }

    static func longBlocksWorkout(
        day: Day, week: TrainerWeek, paces: TrainerPaces, long: TrainerLongPlan
    ) -> TrainerWorkout? {
        guard long.stage < C.longStageCount, let rest = longRest(stage: long.stage) else { return nil }
        let blocks = longBlocks(stage: long.stage, meters: week.longMeters)
        let main = band(paces.long, C.easyBand)
        var parts: [String] = []
        if let evidence = long.evidence { parts.append(T.longEvidence(count: evidence.count, km: evidence.km, longest: blocks.max() ?? 0)) }
        parts.append(T.longBlocksRule(stage: long.stage, blocks: blocks, rest: rest))
        parts.append(longNextText(long: long, meters: week.longMeters))
        return TrainerWorkout(
            day: day, kind: .long, title: T.longBlocksTitle(week.longMeters), totalMeters: week.longMeters,
            steps: longBlockSteps(blocks: blocks, rest: rest, longPace: paces.long),
            paceLow: main.low, paceHigh: main.high, note: nil, rationale: parts.joined(separator: " ")
        )
    }

    static func longNextText(long: TrainerLongPlan, meters: Double) -> String {
        let remaining = max(1, C.longStageAdvanceStreak - long.streak)
        guard long.stage < C.longStageCount else {
            return long.streak >= C.longStageAdvanceStreak ? T.longContinuousSuggestion : T.longContinuousNext
        }
        let next = long.stage + 1
        return T.longNextStage(
            remaining: remaining, next: next, blocks: longBlocks(stage: next, meters: meters), rest: longRest(stage: next),
            fewerPauses: longBlocks(stage: next, meters: meters).count < longBlocks(stage: long.stage, meters: meters).count
        )
    }

    static func longContinuousSuffix(long: TrainerLongPlan, week: TrainerWeek) -> String? {
        guard long.mode == .blocks, long.stage >= C.longStageCount else { return nil }
        return "\(T.longContinuousRule(week.longMeters)) \(longNextText(long: long, meters: week.longMeters))"
    }

    static func recentLongs(history: TrainerHistory, today: Day) -> [TrainerRun] {
        Array(history.runs.filter { $0.kind == .long && $0.day <= today }.sorted { $0.day > $1.day }.prefix(C.longHistoryRuns))
    }

    static func unplannedPauses(_ run: TrainerRun, plan: TrainerPlan?) -> Int {
        let planned = plan?.workouts.first { $0.day == run.day && $0.kind == .long }.map(plannedPauses) ?? 0
        return max(0, (run.pauses ?? 0) - planned)
    }

    static func fadeSamples(of run: TrainerRun, plan: TrainerPlan?) -> [Double] {
        var values = run.fadeKm.map { [Double($0)] } ?? []
        if unplannedPauses(run, plan: plan) > 0, let km = run.firstPauseKm { values.append(Double(km)) }
        return values
    }

    public static func typicalFadeKm(history: TrainerHistory, plan: TrainerPlan?, today: Day) -> Double? {
        median(recentLongs(history: history, today: today).flatMap { fadeSamples(of: $0, plan: plan) })
    }

    public static func longModeSuggestion(history: TrainerHistory, plan: TrainerPlan?, today: Day) -> TrainerLongSuggestion? {
        let runs = recentLongs(history: history, today: today)
        let flagged = runs.filter { $0.fadeKm != nil || unplannedPauses($0, plan: plan) > 0 }.count
        return flagged >= C.longSuggestionMinimum ? TrainerLongSuggestion(flagged: flagged, total: runs.count) : nil
    }

    public static func initialLongStage(history: TrainerHistory, plan: TrainerPlan?, today: Day, meters: Double) -> Int {
        guard let fade = typicalFadeKm(history: history, plan: plan, today: today) else { return 1 }
        let limit = fade * C.longFadeBlockShare * C.metersPerKilometer
        return (1...C.longStageCount).last { stage in
            (longBlocks(stage: stage, meters: meters).max() ?? meters) <= limit
        } ?? 1
    }

    static func longEvidence(history: TrainerHistory, plan: TrainerPlan?, today: Day) -> TrainerLongEvidence? {
        guard let km = typicalFadeKm(history: history, plan: plan, today: today) else { return nil }
        let runs = recentLongs(history: history, today: today)
        let count = runs.filter { !fadeSamples(of: $0, plan: plan).isEmpty }.count
        return TrainerLongEvidence(count: count, km: Int(km.rounded()))
    }

    static func currentLongMeters(_ weeks: [TrainerWeek], today: Day) -> Double {
        weeks.first { $0.start >= today.weekStart && !$0.isRecovery }?.longMeters ?? weeks.last?.longMeters ?? C.minimumLongMeters
    }

    static func closeLongBlocks(
        plan: TrainerPlan, workouts: [TrainerWorkout], history: TrainerHistory
    ) -> TrainerLongOutcome {
        var long = plan.longPlan
        var outcome = TrainerLongOutcome(long: long)
        guard long.mode == .blocks else { return outcome }
        for workout in workouts.sorted(by: { $0.day < $1.day }) where workout.kind == .long {
            guard let run = history.runs.filter({ $0.day == workout.day }).max(by: { $0.meters < $1.meters }),
                  !plan.processedActivityIds.contains(run.activityId),
                  let week = plan.weeks.first(where: { $0.start == workout.day.weekStart }),
                  !week.isRecovery, week.phase != .taper else { continue }
            var reasons: [String] = []
            if run.meters < workout.totalMeters * C.doneShare { reasons.append(T.longMissShort) }
            if (run.pauses ?? 0) > plannedPauses(of: workout) { reasons.append(T.longMissPauses) }
            if let fade = run.fadeKm { reasons.append(T.longMissFade(fade)) }
            let before = long.stage
            if reasons.isEmpty {
                long.streak = min(long.streak + 1, C.longStageAdvanceStreak)
                long.misses = 0
                if long.streak >= C.longStageAdvanceStreak && long.stage < C.longStageCount {
                    long.stage += 1
                    long.streak = 0
                    outcome.sentences.append(T.longAdvanced(workout.day, to: long.stage))
                } else if long.stage >= C.longStageCount && long.streak >= C.longStageAdvanceStreak {
                    outcome.sentences.append(T.longContinuousSuggestion)
                } else {
                    let missing = C.longStageAdvanceStreak - long.streak
                    outcome.sentences.append(
                        long.stage >= C.longStageCount
                            ? T.longClosedLast(workout.day, missing: missing)
                            : T.longClosed(workout.day, missing: missing, next: long.stage + 1)
                    )
                }
            } else {
                long.streak = 0
                long.misses += 1
                var back: Int?
                if long.misses >= C.longStageBackMisses {
                    long.stage = max(1, long.stage - 1)
                    long.misses = 0
                    if long.stage != before { back = long.stage }
                }
                outcome.sentences.append(T.longMissed(workout.day, reasons: reasons, back: back))
            }
            if long.stage != before {
                let meters = workout.totalMeters
                outcome.changes.append(TrainerChange(
                    kind: .changed, title: T.longBlocksTitle(meters),
                    before: T.longStageName(stage: before, blocks: longBlocks(stage: before, meters: meters), rest: longRest(stage: before)),
                    after: T.longStageName(stage: long.stage, blocks: longBlocks(stage: long.stage, meters: meters), rest: longRest(stage: long.stage)),
                    reason: outcome.sentences.last ?? ""
                ))
            }
        }
        outcome.long = long
        return outcome
    }
}
