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
            if let at = toggled.lightWeeks.firstIndex(of: day) { toggled.lightWeeks.remove(at: at) } else { toggled.lightWeeks.append(day) }
            return adjustSkeleton(toggled, history: history, today: today, now: now, trigger: trigger)
        default:
            return adjustSkeleton(plan, history: history, today: today, now: now, trigger: trigger)
        }
    }

    private static func chosenVolumes(_ plan: TrainerPlan, history: TrainerHistory, today: Day) -> (start: Double, peak: Double) {
        let start = plan.startMeters ?? plan.weeks.first?.targetMeters ?? averageWeeklyMeters(history: history, today: today)
        return (start, max(start, plan.peakMeters ?? defaultPeak(from: start)))
    }

    private static func recreate(
        _ plan: TrainerPlan, history: TrainerHistory, today: Day, now: Date, request: TrainerRequest
    ) -> TrainerPlan {
        let keptWeeks = plan.weeks.filter { $0.start < today.weekStart }
        let volumes = chosenVolumes(plan, history: history, today: today)
        let fresh = build(
            target: plan.target, structure: plan.structure, strength: plan.strength, history: history, today: today,
            offset: keptWeeks.count,
            startMeters: volumes.start, peakMeters: volumes.peak, lightWeeks: plan.lightWeeks
        )
        let merged = plan.workouts.filter { $0.day < today } + fresh.workouts
        let freshWeeks = withPlannedMeters(
            keptWeeks + fresh.weeks, workouts: merged, structure: plan.structure, target: plan.target, history: history, today: today
        )
        let oldWindow = plan.workouts.filter { $0.day >= today }
        var changes = workoutChanges(old: oldWindow, new: fresh.workouts, reasons: TrainerChangeReasons())
        if let change = skeletonChange(
            old: plan.weeks, new: freshWeeks, reasons: TrainerChangeReasons(long: T.requestSummary(request, until: request.from)), held: false
        ) {
            changes.insert(change, at: 0)
        }
        changes += newWeekChanges(oldEnd: oldWindow.map(\.day).max(), new: fresh.workouts, weeks: freshWeeks)
        return finish(
            plan, weeks: freshWeeks, workouts: merged,
            paces: fresh.paces, processed: plan.processedActivityIds, trigger: .request(request), now: now,
            summary: T.requestSummary(request, until: request.from), changes: changes
        )
    }

    private static func adjustSkeleton(
        _ plan: TrainerPlan, history: TrainerHistory, today: Day, now: Date, trigger: TrainerTrigger
    ) -> TrainerPlan {
        var paces = paces(history: history, today: today)
        paces.race = racePace(plan.target)
        let currentIndex = plan.weeks.first { $0.start == today.weekStart }?.index ?? plan.weeks.last?.index ?? 0
        var found = TrainerFindings()
        var rebuildFrom = currentIndex + 1
        var processed = plan.processedActivityIds
        var request: TrainerRequest?
        var checkedDay: Day?
        switch trigger {
        case .weekEnded(let index):
            guard let week = plan.weeks.first(where: { $0.index == index }) else { return plan }
            let days = (0..<C.daysPerWeek).map { week.start.adding(days: $0) }
            found = findings(
                workouts: plan.workouts.filter { days.contains($0.day) }, plan: plan, history: history, today: today,
                readinessDays: days, weekly: true
            )
            rebuildFrom = index + 1
            processed += history.runs.filter { days.contains($0.day) }.map(\.activityId)
        case .workout(let id, let day):
            found = findings(
                workouts: plan.workouts.filter { $0.day == day }, plan: plan, history: history, today: today,
                readinessDays: [day], weekly: false
            )
            rebuildFrom = (plan.weeks.first { $0.start == day.weekStart }?.index ?? currentIndex) + 1
            processed.append(id)
            checkedDay = day
        case .request(let value):
            request = value
            found.lowReadiness = value.category == .fatigue
        case .strengthChanged:
            break
        case .lightWeek(let day):
            rebuildFrom = plan.weeks.first { $0.start == day }?.index ?? rebuildFrom
        case .created:
            return plan
        }

        var adjustment = TrainerSkeletonAdjustment()
        if found.longFailed || found.longPaused {
            let planned = found.longPlanned ?? 0
            adjustment.holdProgression = true
            adjustment.longCap = found.longReduced ? planned - C.longReduceMeters : planned
        }
        if found.lowReadiness { adjustment.volumeScale = C.readinessScale }

        let kept = plan.weeks.filter { $0.index < rebuildFrom }
        let volumes = chosenVolumes(plan, history: history, today: today)
        let context = skeletonContext(
            target: plan.target, datedWeeks: plan.target.date == nil ? nil : plan.weeks.count,
            openTotal: max(plan.weeks.count, rebuildFrom + C.openHorizonWeeks - 1),
            peakVolume: volumes.peak, lightWeeks: plan.lightWeeks
        )
        let firstStart = plan.weeks.first { $0.index == rebuildFrom }?.start ?? kept.last?.start.adding(days: C.daysPerWeek) ?? today.weekStart
        let state = derivedState(from: kept) ?? initialState(history: history, today: today, longCap: context.longCap, volume: volumes.start)
        let rebuilt = buildWeeks(context: context, firstIndex: rebuildFrom, firstStart: firstStart, state: state, adjustment: adjustment)
        let skeleton = kept + rebuilt

        let active = activeRequests(of: plan, today: today)
        let requests = active + (request.map { shapesDetail($0.category) ? [$0] : [] } ?? [])
        let past = plan.workouts.filter { $0.day <= today }
        let window = detailWorkouts(
            weeks: skeleton, structure: plan.structure, paces: paces, history: history, target: plan.target,
            today: today, past: past, requests: requests, strength: plan.strength, peakVolume: volumes.peak
        ).map { generated in
            let done = history.runs.contains { $0.day == generated.day }
            return done ? plan.workouts.first { $0.day == generated.day } ?? generated : generated
        }

        let merged = plan.workouts.filter { $0.day < today } + window
        let weeks = withPlannedMeters(
            skeleton, workouts: merged, structure: plan.structure, target: plan.target, history: history, today: today
        )

        var reasons = TrainerChangeReasons()
        reasons.strength = trigger == .strengthChanged
        reasons.requests = requests.map { $0.from...end(of: $0).adding(days: C.returnSearchDays) }
        var sentences: [String] = []
        if found.longFailed || found.longPaused, let day = found.longDay {
            let next = rebuilt.first?.longMeters
            reasons.long = T.longFailure(found, day: day, next: next)
            sentences.append(reasons.long ?? "")
        }
        var suggestion: String?
        for kind in [TrainerDayKind.threshold, .vo2max] {
            if let miss = missedQuality(kind, past: past, history: history, today: today) {
                let legs = legsName(before: miss.day, plan: plan, history: history)
                reasons.quality[kind] = T.qualityMiss(miss, legs: legs)
                guard found.misses.contains(miss) else { continue }
                sentences.append(T.qualityMiss(miss, legs: legs))
                if let legs, repeatedLegsMiss(miss, plan: plan, history: history, today: today) {
                    suggestion = T.strengthSuggestion(name: legs, kind: kind)
                }
            }
        }
        if trigger == .strengthChanged { sentences.append(T.strengthSummary) }
        if case .lightWeek(let day) = trigger, let marked = weeks.first(where: { $0.start == day }) {
            let flipped = zip(plan.weeks, weeks).filter { $0.0.isRecovery != $0.1.isRecovery && $0.1.start != day && $0.1.index >= rebuildFrom }
            let text = plan.lightWeeks.contains(day)
                ? T.lightWeekMarked(day, meters: marked.targetMeters, displaced: flipped.filter { !$0.1.isRecovery }.map { $0.0.start })
                : T.lightWeekCleared(day, meters: marked.targetMeters, added: flipped.filter { $0.1.isRecovery }.map { $0.1.start })
            reasons.volume = text
            sentences.append(text)
        }
        if found.lowReadiness {
            let text = found.readiness.map { T.lowReadiness($0, weekly: isWeekEnded(trigger)) } ?? T.fatigueSummary
            reasons.volume = text
            sentences.append(text)
        }
        if let request, shapesDetail(request.category) || request.category == .fatigue {
            sentences = [T.requestSummary(request, until: end(of: request))]
        }
        if sentences.isEmpty {
            sentences = [weekEndedText(trigger) ?? checkedDay.map(T.workoutChecked) ?? ""]
        }
        let summary = (sentences.prefix(suggestion == nil ? 2 : 1) + (suggestion.map { [$0] } ?? [])).joined(separator: " ")

        let oldWindow = plan.workouts.filter { $0.day >= today }
        var changes = workoutChanges(old: oldWindow, new: window, reasons: reasons)
        let held = adjustment.holdProgression || adjustment.volumeScale != nil
        if let change = skeletonChange(old: plan.weeks, new: weeks, reasons: reasons, held: held) { changes.insert(change, at: 0) }
        changes += newWeekChanges(oldEnd: oldWindow.map(\.day).max(), new: window, weeks: weeks)
        if changes.isEmpty {
            changes = [TrainerChange(kind: .unchanged, title: T.unchangedTitle, reason: sentences.joined(separator: " "))]
        }
        return finish(
            plan, weeks: weeks, workouts: merged, paces: paces, processed: processed,
            trigger: trigger, now: now, summary: summary, changes: changes
        )
    }

    private static func repeatedLegsMiss(_ miss: TrainerQualityMiss, plan: TrainerPlan, history: TrainerHistory, today: Day) -> Bool {
        let previousStart = miss.day.weekStart.adding(days: -C.daysPerWeek)
        return plan.workouts.contains { workout in
            guard workout.day.weekStart == previousStart, workout.day <= today,
                  workout.kind == .threshold || workout.kind == .vo2max,
                  status(of: workout, history: history, today: today).status == .offTarget else { return false }
            return legsName(before: workout.day, plan: plan, history: history) != nil
        }
    }

    private static func isWeekEnded(_ trigger: TrainerTrigger) -> Bool {
        if case .weekEnded = trigger { return true }
        return false
    }

    private static func weekEndedText(_ trigger: TrainerTrigger) -> String? {
        if case .weekEnded(let index) = trigger { return T.weekClosed(index) }
        return nil
    }

    private static func finish(
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
