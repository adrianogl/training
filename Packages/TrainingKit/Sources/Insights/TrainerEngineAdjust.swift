import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    public static func adjust(
        _ plan: TrainerPlan, history: TrainerHistory, today: Day, now: Date, trigger: TrainerTrigger
    ) -> TrainerPlan {
        switch trigger {
        case .created:
            return plan
        case .request(let request) where request.category == .goalChanged || request.category == .other:
            return recreate(plan, history: history, today: today, now: now, request: request)
        case .lightWeek(let day):
            guard day >= today.weekStart, plan.weeks.contains(where: { $0.start == day }) else { return plan }
            var toggled = plan
            if toggled.earlyLightWeeks[day] != nil {
                toggled.earlyLightWeeks[day] = nil
            } else if let at = toggled.lightWeeks.firstIndex(of: day) {
                toggled.lightWeeks.remove(at: at)
            } else {
                toggled.lightWeeks.append(day)
            }
            return adjustSkeleton(toggled, history: history, today: today, now: now, trigger: trigger)
        case .edited(let edit):
            return edit.days.isEmpty ? applyEdit(plan, edit: edit, history: history, today: today, now: now) : plan
        case .readiness(let day, let score):
            return applyReadiness(plan, day: day, score: score, history: history, today: today, now: now)
        case .longModeChanged:
            var toggled = plan
            toggled.longMode = plan.longMode == .blocks ? .continuous : .blocks
            toggled.longStageStreak = 0
            toggled.longStageMisses = 0
            if toggled.longMode == .blocks {
                toggled.longStage = initialLongStage(
                    history: history, plan: plan, today: today, meters: currentLongMeters(plan.weeks, today: today)
                )
            }
            return adjustSkeleton(toggled, history: history, today: today, now: now, trigger: trigger)
        default:
            return adjustSkeleton(plan, history: history, today: today, now: now, trigger: trigger)
        }
    }

    static func chosenVolumes(_ plan: TrainerPlan, history: TrainerHistory, today: Day) -> (start: Double, peak: Double) {
        let start = plan.startMeters ?? plan.weeks.first?.targetMeters ?? averageWeeklyMeters(history: history, today: today)
        return (start, max(start, plan.peakMeters ?? defaultPeak(from: start)))
    }

    private static func recreate(
        _ plan: TrainerPlan, history: TrainerHistory, today: Day, now: Date, request: TrainerRequest
    ) -> TrainerPlan {
        let text = T.requestSummary(request, until: request.from)
        return rebuild(
            plan, from: plan, history: history, today: today, now: now, trigger: .request(request), summary: text,
            reasons: TrainerChangeReasons(long: text), leading: [], notify: { $0 >= request.from }
        )
    }

    static func rebuild(
        _ plan: TrainerPlan, from source: TrainerPlan, history: TrainerHistory, today: Day, now: Date, trigger: TrainerTrigger,
        summary: String, reasons: TrainerChangeReasons, leading: [TrainerChange], notify: ((Day) -> Bool)?
    ) -> TrainerPlan {
        let keptWeeks = source.weeks.filter { $0.start < today.weekStart }
        let volumes = chosenVolumes(source, history: history, today: today)
        let fresh = build(
            target: source.target, structure: source.structure, strength: source.strength, history: history, today: today,
            offset: keptWeeks.count,
            startMeters: volumes.start, peakMeters: volumes.peak, lightWeeks: source.lightWeeks,
            longMode: source.longMode, longStage: source.longStage, paceOverrides: source.paceOverrides,
            earlyLightWeeks: source.earlyLightWeeks, calmWeeks: source.calmWeeks,
            lastRecovery: keptWeeks.last { $0.isRecovery }?.index, outAndBack: source.outAndBack
        )
        let protected = protectingEdited(
            existing: plan.workouts, generated: fresh.workouts, history: history, keepDone: true, notify: notify
        )
        let merged = plan.workouts.filter { $0.day < today } + protected.workouts
        let freshWeeks = withPlannedMeters(
            keptWeeks + fresh.weeks, workouts: merged, structure: source.structure, target: source.target, history: history, today: today,
            paces: fresh.paces
        )
        let oldWindow = plan.workouts.filter { $0.day >= today }
        var changes = groupingDistant(
            workoutChanges(old: oldWindow, new: protected.workouts, reasons: TrainerChangeReasons(override: reasons.override)),
            today: today, weeks: freshWeeks
        )
        if let change = skeletonChange(old: plan.weeks, new: freshWeeks, reasons: reasons, held: false) {
            changes.insert(change, at: 0)
        }
        changes = leading + changes
        changes += protected.notices
        changes += newWeekChanges(oldEnd: oldWindow.map(\.day).max(), new: protected.workouts, weeks: freshWeeks)
        return finish(
            source, weeks: freshWeeks, workouts: merged, paces: fresh.paces, processed: plan.processedActivityIds, trigger: trigger,
            now: now, summary: summary, changes: changes
        )
    }

    static func protectingEdited(
        existing: [TrainerWorkout], generated: [TrainerWorkout], history: TrainerHistory, keepDone: Bool, notify: ((Day) -> Bool)?
    ) -> (workouts: [TrainerWorkout], notices: [TrainerChange]) {
        var notices: [TrainerChange] = []
        let workouts = generated.map { item -> TrainerWorkout in
            guard let current = existing.first(where: { $0.day == item.day }) else { return item }
            if keepDone && history.runs.contains(where: { $0.day == item.day }) { return current }
            guard current.edited else { return item }
            if let notify, notify(item.day), !sameContent(current, item) {
                notices.append(TrainerChange(
                    kind: .unchanged, day: item.day, title: T.editedKeptTitle, reason: T.editedKept
                ))
            }
            return current
        }
        return (workouts, notices)
    }

    private static func adjustSkeleton(
        _ plan: TrainerPlan, history: TrainerHistory, today: Day, now: Date, trigger: TrainerTrigger
    ) -> TrainerPlan {
        let paces = resolvedPaces(history: history, today: today, target: plan.target, overrides: plan.paceOverrides)
        let currentIndex = plan.weeks.first { $0.start == today.weekStart }?.index ?? plan.weeks.last?.index ?? 0
        var found = TrainerFindings()
        var rebuildFrom = currentIndex + 1
        var processed = plan.processedActivityIds
        var request: TrainerRequest?
        var checkedDay: Day?
        var longScope: [TrainerWorkout] = []
        var decision: TrainerSignalDecision?
        switch trigger {
        case .weekEnded(let index):
            guard let week = plan.weeks.first(where: { $0.index == index }) else { return plan }
            let days = (0..<C.daysPerWeek).map { week.start.adding(days: $0) }
            found = findings(
                workouts: plan.workouts.filter { days.contains($0.day) }, plan: plan, history: history, today: today,
                readinessDays: days, weekly: true
            )
            found.signals = signals(plan: plan, history: history, week: week)
            decision = signalDecision(plan: plan, closed: week, signals: found.signals)
            longScope = plan.workouts.filter { days.contains($0.day) }
            rebuildFrom = index + 1
            processed += history.runs.filter { days.contains($0.day) }.map(\.activityId)
        case .workout(let id, let day):
            found = findings(
                workouts: plan.workouts.filter { $0.day == day }, plan: plan, history: history, today: today,
                readinessDays: [day], weekly: false
            )
            longScope = plan.workouts.filter { $0.day == day }
            rebuildFrom = (plan.weeks.first { $0.start == day.weekStart }?.index ?? currentIndex) + 1
            processed.append(id)
            checkedDay = day
        case .request(let value):
            request = value
            found.lowReadiness = value.category == .fatigue
        case .strengthChanged, .longModeChanged:
            break
        case .lightWeek(let day):
            rebuildFrom = plan.weeks.first { $0.start == day }?.index ?? rebuildFrom
        case .created, .edited, .readiness:
            return plan
        }

        let closing = closeLongBlocks(plan: plan, workouts: longScope, history: history)
        var working = plan
        working.apply(closing.long)
        var longDetail = working.longPlan
        if longDetail.mode == .blocks { longDetail.evidence = longEvidence(history: history, plan: plan, today: today) }

        var adjustment = TrainerSkeletonAdjustment()
        if found.longFailed || found.longPaused {
            let planned = found.longPlanned ?? 0
            adjustment.holdProgression = true
            adjustment.longCap = found.longReduced ? planned - C.longReduceMeters : planned
        }
        if found.lowReadiness { adjustment.volumeScale = C.readinessScale }
        let nextStart = plan.weeks.first { $0.index == rebuildFrom }?.start
        switch decision {
        case .early(let kind):
            if let nextStart { working.earlyLightWeeks[nextStart] = kind }
        case .calm:
            if let nextStart, !working.calmWeeks.contains(nextStart) { working.calmWeeks.append(nextStart) }
        case nil:
            break
        }

        let kept = plan.weeks.filter { $0.index < rebuildFrom }
        let volumes = chosenVolumes(plan, history: history, today: today)
        let context = skeletonContext(
            target: plan.target, datedWeeks: plan.target.date == nil ? nil : plan.weeks.count,
            openTotal: max(plan.weeks.count, rebuildFrom + C.openHorizonWeeks - 1),
            peakVolume: volumes.peak, paces: paces, lightWeeks: plan.lightWeeks, earlyLightWeeks: working.earlyLightWeeks,
            calmWeeks: working.calmWeeks, outAndBack: plan.outAndBack
        )
        let firstStart = plan.weeks.first { $0.index == rebuildFrom }?.start ?? kept.last?.start.adding(days: C.daysPerWeek) ?? today.weekStart
        let state = derivedState(from: kept) ?? initialState(history: history, today: today, longCap: context.longCap(at: volumes.start), volume: volumes.start)
        let sized = sizedWeeks(
            buildWeeks(context: context, firstIndex: rebuildFrom, firstStart: firstStart, state: state, adjustment: adjustment), paces: paces
        )
        var waved = Array(wavedLongs(
            kept + sized, from: rebuildFrom, structure: plan.structure, target: plan.target, paces: paces, mode: working.longMode
        ).dropFirst(kept.count))
        if let cap = adjustment.longCap, !waved.isEmpty { waved[0].longMeters = min(waved[0].longMeters, cap) }
        let rebuilt = evenLongs(longestLongs(waved, structure: plan.structure, target: plan.target, history: history, today: today, paces: paces), paces: paces, firstCap: adjustment.longCap)
        let skeleton = labeledVo2(kept + rebuilt, from: rebuildFrom)

        let active = activeRequests(of: plan, today: today)
        let requests = active + (request.map { shapesDetail($0.category) ? [$0] : [] } ?? [])
        let past = plan.workouts.filter { $0.day <= today }
        let generatedWindow = detailWorkouts(
            weeks: skeleton, structure: plan.structure, paces: paces, history: history, target: plan.target,
            today: today, past: past, requests: requests, peakVolume: volumes.peak, long: longDetail
        ).map { generated in
            let done = history.runs.contains { $0.day == generated.day }
            return done ? plan.workouts.first { $0.day == generated.day } ?? generated : generated
        }
        let protected = protectingEdited(
            existing: plan.workouts, generated: generatedWindow, history: history, keepDone: false, notify: keepNotice(for: request)
        )
        let window = protected.workouts

        let merged = plan.workouts.filter { $0.day < today } + window
        let weeks = withPlannedMeters(
            skeleton, workouts: merged, structure: plan.structure, target: plan.target, history: history, today: today, paces: paces
        )

        var reasons = TrainerChangeReasons()
        reasons.requests = requests.map { $0.from...end(of: $0).adding(days: C.returnSearchDays) }
        var sentences: [String] = []
        if found.longFailed || found.longPaused, let day = found.longDay {
            let next = rebuilt.first?.longMeters
            reasons.long = T.longFailure(found, day: day, next: next)
            sentences.append(reasons.long ?? "")
        }
        for kind in [TrainerDayKind.threshold, .vo2max] {
            if let miss = missedQuality(kind, past: past, history: history, today: today) {
                reasons.quality[kind] = T.qualityMiss(miss)
                guard found.misses.contains(miss) else { continue }
                sentences.append(T.qualityMiss(miss))
            }
        }
        if trigger == .strengthChanged { sentences.append(T.strengthSummary) }
        sentences += closing.sentences
        if !closing.changes.isEmpty { reasons.long = closing.sentences.last }
        var longModeChange: TrainerChange?
        if trigger == .longModeChanged {
            let meters = currentLongMeters(weeks, today: today)
            let stage = working.longStage
            let blocks = longBlocks(stage: stage, meters: meters)
            let text = T.longModeChanged(to: working.longMode, stage: stage, blocks: blocks, rest: longRest(stage: stage))
            let previous: TrainerLongMode = working.longMode == .blocks ? .continuous : .blocks
            longModeChange = TrainerChange(
                kind: .changed, title: T.longModeTitle,
                before: T.longModeSummary(previous, stage: stage, blocks: blocks, rest: longRest(stage: stage)),
                after: T.longModeSummary(working.longMode, stage: stage, blocks: blocks, rest: longRest(stage: stage)),
                reason: text
            )
            reasons.long = text
            sentences.append(text)
        }
        if case .lightWeek(let day) = trigger, let marked = weeks.first(where: { $0.start == day }) {
            let flipped = zip(plan.weeks, weeks).filter { $0.0.isRecovery != $0.1.isRecovery && $0.1.start != day && $0.1.index >= rebuildFrom }
            let text = plan.lightWeeks.contains(day)
                ? T.lightWeekMarked(day, meters: marked.targetMeters, displaced: flipped.filter { !$0.1.isRecovery }.map { $0.0.start })
                : T.lightWeekCleared(day, meters: marked.targetMeters, added: flipped.filter { $0.1.isRecovery }.map { $0.1.start })
            reasons.volume = text
            sentences.append(text)
        }
        if found.lowReadiness {
            let text = found.readiness.map { T.lowReadiness($0) } ?? T.fatigueSummary
            reasons.volume = text
            sentences.append(text)
        }
        if let decision {
            let text = T.signalWeek(found.signals, early: decision != .calm)
            reasons.volume = text
            sentences.insert(text, at: 0)
        }
        if let request, shapesDetail(request.category) || request.category == .fatigue {
            sentences = [T.requestSummary(request, until: end(of: request))]
        }
        if sentences.isEmpty {
            sentences = [weekEndedText(trigger) ?? checkedDay.map(T.workoutChecked) ?? ""]
        }
        let summary = sentences.prefix(2).joined(separator: " ")

        let oldWindow = plan.workouts.filter { $0.day >= today }
        var changes = groupingDistant(workoutChanges(old: oldWindow, new: window, reasons: reasons), today: today, weeks: weeks)
        let held = adjustment.holdProgression || adjustment.volumeScale != nil || decision != nil
        if let change = skeletonChange(old: plan.weeks, new: weeks, reasons: reasons, held: held) { changes.insert(change, at: 0) }
        changes += closing.changes
        changes += protected.notices
        if let longModeChange { changes.insert(longModeChange, at: 0) }
        changes += newWeekChanges(oldEnd: oldWindow.map(\.day).max(), new: window, weeks: weeks)
        if changes.isEmpty {
            changes = [TrainerChange(kind: .unchanged, title: T.unchangedTitle, reason: sentences.joined(separator: " "))]
        }
        return finish(
            working, weeks: weeks, workouts: merged, paces: paces, processed: processed,
            trigger: trigger, now: now, summary: summary, changes: changes
        )
    }

    private static func keepNotice(for request: TrainerRequest?) -> ((Day) -> Bool)? {
        guard let request, request.category == .fatigue || shapesDetail(request.category) else { return nil }
        return { day in
            day >= request.from && (!shapesDetail(request.category) || day <= end(of: request))
        }
    }

    private static func weekEndedText(_ trigger: TrainerTrigger) -> String? {
        if case .weekEnded(let index) = trigger { return T.weekClosed(index) }
        return nil
    }

    static func finish(
        _ plan: TrainerPlan, weeks: [TrainerWeek], workouts: [TrainerWorkout], paces: TrainerPaces, processed: [Int64],
        trigger: TrainerTrigger, now: Date, summary: String, changes: [TrainerChange]
    ) -> TrainerPlan {
        var result = plan
        result.weeks = weeks
        result.workouts = workouts
        result.paces = paces
        result.processedActivityIds = processed
        result.versions.append(TrainerVersion(
            number: (plan.versions.last?.number ?? 0) + 1, createdAt: now, trigger: trigger, summary: summary, changes: changes
        ))
        return result
    }
}
