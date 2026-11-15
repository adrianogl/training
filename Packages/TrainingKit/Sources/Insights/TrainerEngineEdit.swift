import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    public static func volumes(of plan: TrainerPlan, history: TrainerHistory, today: Day) -> (start: Double, peak: Double) {
        chosenVolumes(plan, history: history, today: today)
    }

    public static func makeEdit(
        for plan: TrainerPlan, target: TrainerTarget, startMeters: Double, peakMeters: Double, structure: [Int: TrainerDayKind],
        strength: [TrainerStrengthSession], longMode: TrainerLongMode, paceOverrides: [TrainerPaceKind: Double],
        history: TrainerHistory, today: Day, dayPreference: TrainerDayPreference? = nil
    ) -> TrainerEdit {
        let volumes = chosenVolumes(plan, history: history, today: today)
        let volumesChanged = startMeters != volumes.start || peakMeters != volumes.peak
        return TrainerEdit(
            target: target != plan.target ? target : nil,
            startMeters: volumesChanged ? startMeters : nil,
            peakMeters: volumesChanged ? peakMeters : nil,
            structure: structure != plan.structure ? structure : nil,
            strength: sortedStrength(strength) != sortedStrength(plan.strength) ? strength : nil,
            longMode: longMode != plan.longMode ? longMode : nil,
            paceOverrides: paceOverrides != plan.paceOverrides ? paceOverrides : nil,
            dayPreference: dayPreference.flatMap { $0 != plan.dayPreference ? $0 : nil }
        )
    }

    public static func previewEdit(
        _ plan: TrainerPlan, edit: TrainerEdit, history: TrainerHistory, today: Day, now: Date
    ) -> [TrainerChange] {
        let result = adjust(plan, history: history, today: today, now: now, trigger: .edited(edit))
        guard result.versions.count > plan.versions.count else { return [] }
        return result.versions.last?.changes ?? []
    }

    static func applyEdit(_ plan: TrainerPlan, edit: TrainerEdit, history: TrainerHistory, today: Day, now: Date) -> TrainerPlan {
        var source = plan
        if let target = edit.target { source.target = target }
        if let start = edit.startMeters { source.startMeters = start }
        if let peak = edit.peakMeters { source.peakMeters = peak }
        if let structure = edit.structure { source.structure = structure }
        if let strength = edit.strength { source.strength = strength }
        if let overrides = edit.paceOverrides { source.paceOverrides = overrides }
        if let preference = edit.dayPreference { source.dayPreference = preference }
        if let mode = edit.longMode, mode != plan.longMode {
            source.longMode = mode
            source.longStageStreak = 0
            source.longStageMisses = 0
            if mode == .blocks {
                source.longStage = initialLongStage(
                    history: history, plan: plan, today: today, meters: currentLongMeters(plan.weeks, today: today)
                )
            }
        }
        let fields = editedFields(old: plan, new: source, history: history, today: today)
        guard !fields.isEmpty else { return plan }
        let reasons = TrainerChangeReasons(override: T.editedByYouReason, long: T.editedByYouReason)
        let rebuilt = rebuild(
            plan, from: source, history: history, today: today, now: now, trigger: .edited(edit),
            summary: T.editedPlanSummary(fields), reasons: reasons, leading: [], notify: { _ in true }
        )
        let leading = editChanges(old: plan, new: rebuilt, today: today)
        var result = rebuilt
        var version = result.versions.removeLast()
        version.changes = leading + version.changes
        result.versions.append(version)
        return result
    }

    private static func sortedStrength(_ sessions: [TrainerStrengthSession]) -> [TrainerStrengthSession] {
        sessions.sorted { ($0.weekday, $0.id.uuidString) < ($1.weekday, $1.id.uuidString) }
    }

    private static func editedFields(old: TrainerPlan, new: TrainerPlan, history: TrainerHistory, today: Day) -> [String] {
        let before = chosenVolumes(old, history: history, today: today)
        let after = chosenVolumes(new, history: history, today: today)
        var fields: [String] = []
        if old.target != new.target { fields.append(T.editFieldTarget) }
        if before.start != after.start || before.peak != after.peak { fields.append(T.editFieldVolumes) }
        if old.structure != new.structure || old.dayPreference != new.dayPreference { fields.append(T.editFieldStructure) }
        if sortedStrength(old.strength) != sortedStrength(new.strength) { fields.append(T.editFieldStrength) }
        if old.longMode != new.longMode { fields.append(T.editFieldLong) }
        if old.paceOverrides != new.paceOverrides { fields.append(T.editFieldPaces) }
        return fields
    }

    private static func editChanges(old: TrainerPlan, new: TrainerPlan, today: Day) -> [TrainerChange] {
        var changes: [TrainerChange] = []
        if old.target != new.target {
            changes.append(TrainerChange(
                kind: .changed, title: T.editTargetTitle, before: old.target.name, after: new.target.name, reason: T.editedByYouReason
            ))
        }
        for kind in TrainerPaceKind.allCases where old.paceOverrides[kind] != new.paceOverrides[kind] {
            let before = paceValue(kind, in: old.paces)
            let after = paceValue(kind, in: new.paces)
            guard let before, let after, abs(before - after) >= 1 else { continue }
            changes.append(TrainerChange(
                kind: .changed, title: T.editedPaceTitle(kind), before: "\(T.pace(before))/km", after: "\(T.pace(after))/km",
                reason: T.editedPaceReason(manual: new.paceOverrides[kind] != nil)
            ))
        }
        if old.longMode != new.longMode {
            let meters = currentLongMeters(new.weeks, today: today)
            let stage = new.longStage
            let blocks = longBlocks(stage: stage, meters: meters)
            let rest = longRest(stage: stage)
            changes.append(TrainerChange(
                kind: .changed, title: T.longModeTitle,
                before: T.longModeSummary(old.longMode, stage: stage, blocks: blocks, rest: rest),
                after: T.longModeSummary(new.longMode, stage: stage, blocks: blocks, rest: rest),
                reason: T.longModeChanged(to: new.longMode, stage: stage, blocks: blocks, rest: rest)
            ))
        }
        return changes
    }

    private static func paceValue(_ kind: TrainerPaceKind, in paces: TrainerPaces) -> Double? {
        switch kind {
        case .easy: paces.easy
        case .long: paces.long
        case .threshold: paces.threshold
        case .vo2max: paces.vo2max
        case .race: paces.race
        }
    }

    public static func nextBlockMeters(_ meters: Double, up: Bool) -> Double {
        let step: Double
        if up {
            step = meters < C.editShortBlockLimitMeters ? C.editShortBlockStepMeters : C.editBlockStepMeters
        } else {
            step = meters <= C.editShortBlockLimitMeters ? C.editShortBlockStepMeters : C.editBlockStepMeters
        }
        let next = up ? meters + step : meters - step
        return min(max(next, C.editMinimumBlockMeters), C.editMaximumBlockMeters)
    }

    public static let editRepeatsRange = C.editRepeatsRange
    public static let editDistanceStepMeters = C.editDistanceStepMeters
    public static let editDistanceRange = C.editMinimumDistanceMeters...C.editMaximumDistanceMeters
    public static let editRestStepSeconds = C.editRestStepSeconds
    public static let editRestRange = C.editMinimumRestSeconds...C.editMaximumRestSeconds
    public static let editPaceStepSeconds = C.editPaceStepSeconds
    public static let editPaceRange = C.editMinimumPaceSeconds...C.editMaximumPaceSeconds
    public static let editPaceBand = C.qualityBand

    private static func mainStep(of workout: TrainerWorkout) -> TrainerStep? {
        workout.steps.first { $0.kind == .work && $0.method != .repetition }
    }

    private static func center(low: Double?, high: Double?) -> Double? {
        guard let low, let high else { return nil }
        return (low + high) / 2
    }

    private static func stepsMeters(_ steps: [TrainerStep]) -> Double {
        steps.reduce(0.0) { $0 + $1.meters * Double($1.repeats) }
    }

    public static func isEditable(_ workout: TrainerWorkout) -> Bool { draft(of: workout) != nil }

    public static func draft(of workout: TrainerWorkout) -> TrainerWorkoutDraft? {
        switch workout.kind {
        case .off, .race:
            return nil
        case .threshold, .vo2max:
            guard let main = mainStep(of: workout), let pace = center(low: main.paceLow, high: main.paceHigh) else { return nil }
            let rest = workout.steps.first { $0.kind == .recovery && $0.restSeconds != nil }?.restSeconds ?? C.editDefaultRestSeconds
            return TrainerWorkoutDraft(
                isQuality: true, repeats: main.repeats, blockMeters: main.meters, pace: pace, restSeconds: rest, totalMeters: workout.totalMeters
            )
        case .easy, .optionalEasy, .long:
            guard let pace = center(low: workout.paceLow, high: workout.paceHigh) else { return nil }
            return TrainerWorkoutDraft(
                isQuality: false, repeats: 1, blockMeters: workout.totalMeters, pace: pace, restSeconds: C.editDefaultRestSeconds,
                totalMeters: workout.totalMeters
            )
        }
    }

    public static func applying(_ draft: TrainerWorkoutDraft, to workout: TrainerWorkout) -> TrainerWorkout {
        var result = draft.isQuality ? qualityEdit(draft, workout) : steadyEdit(draft, workout)
        result.edited = true
        return result
    }

    private static func qualityEdit(_ draft: TrainerWorkoutDraft, _ workout: TrainerWorkout) -> TrainerWorkout {
        guard let first = workout.steps.firstIndex(where: { $0.kind == .work && $0.method != .repetition }),
              let main = mainStep(of: workout) else { return workout }
        let band = band(draft.pace, C.qualityBand)
        let closing = workout.steps.firstIndex { $0.method == .repetition }
        var steps = Array(workout.steps[..<first])
        steps.append(TrainerStep(
            kind: .work, repeats: draft.repeats, meters: draft.blockMeters, paceLow: band.low, paceHigh: band.high, method: main.method
        ))
        if draft.repeats > 1 { steps.append(TrainerStep(kind: .recovery, repeats: draft.repeats - 1, meters: 0, restSeconds: draft.restSeconds)) }
        if let closing {
            steps.append(TrainerStep(kind: .recovery, meters: 0, restSeconds: draft.restSeconds))
            steps += workout.steps[closing...]
        }
        let session = TrainerQualitySession(
            kind: workout.kind, method: main.method ?? .tempo, blocks: [TrainerQualityBlock(repeats: draft.repeats, meters: draft.blockMeters)],
            closing: closing != nil
        )
        var result = workout
        result.steps = steps
        result.totalMeters = stepsMeters(steps)
        result.title = T.title(kind: workout.kind, meters: 0, session: session)
        result.paceLow = band.low
        result.paceHigh = band.high
        return result
    }

    private static func steadyEdit(_ draft: TrainerWorkoutDraft, _ workout: TrainerWorkout) -> TrainerWorkout {
        let current = center(low: workout.paceLow, high: workout.paceHigh) ?? draft.pace
        let shift = draft.pace - current
        let total = min(max(draft.totalMeters, C.editMinimumDistanceMeters), C.editMaximumDistanceMeters)
        var result = workout
        result.paceLow = workout.paceLow.map { $0 + shift }
        result.paceHigh = workout.paceHigh.map { $0 + shift }
        if plannedPauses(of: workout) > 0, let rest = workout.steps.first(where: { $0.restSeconds != nil })?.restSeconds {
            let blocks = scaledBlocks(blockSizes(of: workout), to: total)
            result.steps = longBlockSteps(blocks: blocks, rest: rest, longPace: draft.pace)
            result.title = T.longBlocksTitle(total)
        } else {
            var steps = workout.steps.map { step -> TrainerStep in
                var shifted = step
                shifted.paceLow = step.paceLow.map { $0 + shift }
                shifted.paceHigh = step.paceHigh.map { $0 + shift }
                return shifted
            }
            if let index = steps.firstIndex(where: { $0.kind == .steady && $0.meters > 0 }) {
                let others = stepsMeters(steps) - steps[index].meters * Double(steps[index].repeats)
                steps[index].meters = max(total - others, C.halfKilometer)
            }
            result.steps = steps
            result.title = T.title(kind: workout.kind, meters: stepsMeters(steps))
        }
        result.totalMeters = stepsMeters(result.steps)
        return result
    }

    private static func scaledBlocks(_ sizes: [Double], to total: Double) -> [Double] {
        let old = sizes.reduce(0, +)
        guard old > 0, sizes.count > 1 else { return [total] }
        var blocks: [Double] = []
        var used = 0.0
        for size in sizes.dropLast() {
            let scaled = max(roundHalfKilometers(size * total / old), C.halfKilometer)
            guard used + scaled + C.halfKilometer <= total else { break }
            blocks.append(scaled)
            used += scaled
        }
        blocks.append(total - used)
        return blocks
    }

    private static func replace(_ plan: TrainerPlan, with workouts: [TrainerWorkout], weeks: [TrainerWeek]? = nil) -> TrainerPlan {
        var result = plan
        result.workouts = workouts
        if let weeks { result.weeks = weeks }
        return result
    }

    private static func weeks(of plan: TrainerPlan, adding meters: Double, on day: Day) -> [TrainerWeek] {
        plan.weeks.map { week in
            guard week.start == day.weekStart else { return week }
            var shifted = week
            shifted.plannedMeters += meters
            return shifted
        }
    }

    private static func editChange(old: TrainerWorkout, new: TrainerWorkout, reason: String) -> TrainerChange {
        TrainerChange(
            kind: .changed, day: new.day, title: changeTitle(new), before: describe(old), after: describe(new), reason: reason
        )
    }

    public static func editWorkout(_ plan: TrainerPlan, _ edited: TrainerWorkout, now: Date) -> TrainerPlan {
        guard let index = plan.workouts.firstIndex(where: { $0.day == edited.day }) else { return plan }
        var next = edited
        next.edited = true
        let old = plan.workouts[index]
        guard old != next else { return plan }
        var workouts = plan.workouts
        workouts[index] = next
        let weeks = weeks(of: plan, adding: next.totalMeters - old.totalMeters, on: next.day)
        return finish(
            replace(plan, with: workouts), weeks: weeks, workouts: workouts, paces: plan.paces, processed: plan.processedActivityIds,
            trigger: .edited(TrainerEdit(days: [next.day])), now: now, summary: T.editedWorkoutSummary(next.day),
            changes: [editChange(old: old, new: next, reason: T.editedByYou)]
        )
    }

    public static func swapWorkouts(_ plan: TrainerPlan, _ first: Day, _ second: Day, now: Date) -> TrainerPlan {
        guard first != second, first.weekStart == second.weekStart,
              let firstIndex = plan.workouts.firstIndex(where: { $0.day == first }),
              let secondIndex = plan.workouts.firstIndex(where: { $0.day == second }) else { return plan }
        var workouts = plan.workouts
        var moved = workouts[secondIndex]
        moved.day = first
        moved.edited = true
        var other = workouts[firstIndex]
        other.day = second
        other.edited = true
        let oldFirst = workouts[firstIndex]
        let oldSecond = workouts[secondIndex]
        workouts[firstIndex] = moved
        workouts[secondIndex] = other
        let changes = [
            editChange(old: oldFirst, new: moved, reason: T.editedByYou),
            editChange(old: oldSecond, new: other, reason: T.editedByYou),
        ].sorted { ($0.day?.iso ?? "") < ($1.day?.iso ?? "") }
        return finish(
            replace(plan, with: workouts), weeks: plan.weeks, workouts: workouts, paces: plan.paces,
            processed: plan.processedActivityIds, trigger: .edited(TrainerEdit(days: [first, second].sorted())), now: now,
            summary: T.editedSwapSummary(min(first, second), max(first, second)), changes: changes
        )
    }

    public static func revertWorkout(
        _ plan: TrainerPlan, day: Day, history: TrainerHistory, today: Day, now: Date
    ) -> TrainerPlan {
        guard let index = plan.workouts.firstIndex(where: { $0.day == day && $0.edited }) else { return plan }
        let old = plan.workouts[index]
        let volumes = chosenVolumes(plan, history: history, today: today)
        var long = plan.longPlan
        if long.mode == .blocks { long.evidence = longEvidence(history: history, plan: plan, today: today) }
        let suggested = detailWorkouts(
            weeks: plan.weeks, structure: plan.structure, paces: plan.paces, history: history, target: plan.target, today: today,
            past: plan.workouts.filter { $0.day <= today }, requests: activeRequests(of: plan, today: today), peakVolume: volumes.peak,
            long: long
        ).first { $0.day == day }
        var workouts = plan.workouts
        guard var next = suggested else {
            workouts[index].edited = false
            return replace(plan, with: workouts)
        }
        next.edited = false
        workouts[index] = next
        let weeks = weeks(of: plan, adding: next.totalMeters - old.totalMeters, on: day)
        return finish(
            replace(plan, with: workouts), weeks: weeks, workouts: workouts, paces: plan.paces, processed: plan.processedActivityIds,
            trigger: .edited(TrainerEdit(days: [day])), now: now, summary: T.editedRevertSummary(day),
            changes: [editChange(old: old, new: next, reason: T.editedRevertedReason)]
        )
    }
}
