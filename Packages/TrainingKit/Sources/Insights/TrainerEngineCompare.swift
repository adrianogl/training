import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static func summary(of workout: TrainerWorkout) -> String { describe(workout) }

    public static func classify(_ external: TrainerExternalWorkout, plan: TrainerPlan) -> TrainerDayKind {
        guard external.totalMeters > 0 || !external.steps.isEmpty else { return .off }
        let name = external.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        func named(_ words: [String]) -> Bool { words.contains { name.localizedCaseInsensitiveContains($0) } }
        if named(C.vo2NameWords) { return .vo2max }
        if named(C.thresholdNameWords) { return .threshold }
        if named(C.longNameWords) { return .long }
        let work = external.steps.filter { $0.kind == .work }
        if isQualityShape(work, paces: plan.paces) { return qualityKind(of: work, paces: plan.paces) }
        if named(C.easyNameWords) { return .easy }
        let longMeters = plan.weeks.first { $0.start == external.day.weekStart }.map { $0.longMeters * C.externalLongShare }
        return external.totalMeters >= (longMeters ?? C.externalLongFallbackMeters) ? .long : .easy
    }

    private static func isQualityShape(_ work: [TrainerStep], paces: TrainerPaces) -> Bool {
        if work.reduce(0, { $0 + $1.repeats }) >= C.externalMinimumBlocks { return true }
        guard work.count == 1, let pace = averagePace(work) else { return false }
        return pace <= paces.threshold + C.externalTempoMarginSeconds
    }

    private static func qualityKind(of work: [TrainerStep], paces: TrainerPaces) -> TrainerDayKind {
        if let pace = averagePace(work) { return pace <= (paces.vo2max + paces.threshold) / 2 ? .vo2max : .threshold }
        return (work.map(\.meters).max() ?? 0) <= C.externalVo2BlockMeters ? .vo2max : .threshold
    }

    private static func averagePace(_ steps: [TrainerStep]) -> Double? {
        let main = steps.filter { $0.kind == .work && $0.method != .repetition }
        let source = main.isEmpty ? steps.filter { $0.kind == .steady } : main
        var weighted = 0.0
        var meters = 0.0
        for step in source {
            guard let low = step.paceLow, let high = step.paceHigh else { continue }
            let size = step.meters * Double(step.repeats)
            weighted += (low + high) / 2 * size
            meters += size
        }
        return meters > 0 ? weighted / meters : nil
    }

    private static func isQuality(_ kind: TrainerDayKind?) -> Bool { kind == .threshold || kind == .vo2max }

    private static func comparisonKind(_ workout: TrainerWorkout?) -> TrainerDayKind {
        guard let workout else { return .off }
        return workout.kind == .optionalEasy ? .easy : workout.kind
    }

    private static func closeKinds(_ first: TrainerDayKind, _ second: TrainerDayKind) -> Bool {
        let pair: Set<TrainerDayKind> = [first, second]
        return pair == [.threshold, .vo2max] || pair == [.easy, .long]
    }

    private static func match(beta: TrainerDayKind, external: TrainerDayKind, betaMeters: Double, externalMeters: Double) -> TrainerComparisonMatch {
        if beta == external {
            guard beta != .off else { return .same }
            let reference = max(betaMeters, externalMeters)
            return reference > 0 && abs(betaMeters - externalMeters) / reference <= C.sameDistanceShare ? .same : .similar
        }
        return closeKinds(beta, external) ? .similar : .different
    }

    private static func distanceError(planned: Double, run: TrainerRun) -> Double {
        run.meters > 0 ? abs(planned - run.meters) / run.meters : 0
    }

    private static func closerPlan(
        beta: TrainerWorkout, external: TrainerExternalWorkout, kind: TrainerDayKind, run: TrainerRun
    ) -> TrainerComparisonCloser {
        let betaPace = averagePace(beta.steps)
        let externalPace = averagePace(external.steps)
        let runPace = run.workPaceSeconds ?? (isQuality(kind) || run.meters <= 0 ? nil : run.seconds / run.meters * C.metersPerKilometer)
        var betaScore = distanceError(planned: beta.totalMeters, run: run)
        var externalScore = distanceError(planned: external.totalMeters, run: run)
        if let betaPace, let externalPace, let runPace, runPace > 0 {
            betaScore += abs(betaPace - runPace) / runPace
            externalScore += abs(externalPace - runPace) / runPace
        }
        if abs(betaScore - externalScore) < C.closerTieShare { return .tie }
        return betaScore < externalScore ? .beta : .external
    }

    public static func compare(
        plan: TrainerPlan, external: [TrainerExternalWorkout], history: TrainerHistory, week start: Day, today: Day
    ) -> TrainerComparisonWeek {
        var days: [TrainerComparisonDay] = []
        var sameKind = 0
        for offset in 0..<C.daysPerWeek {
            let day = start.adding(days: offset)
            let beta = plan.workouts.first { $0.day == day }
            let outside = external.filter { $0.day == day }.max { $0.totalMeters < $1.totalMeters }
            let betaKind = comparisonKind(beta)
            let outsideKind = outside.map { classify($0, plan: plan) } ?? .off
            guard betaKind != .off || outsideKind != .off else { continue }
            if betaKind == outsideKind { sameKind += 1 }
            let run = day <= today ? history.runs.filter { $0.day == day }.max { $0.meters < $1.meters } : nil
            var closer: TrainerComparisonCloser?
            if let beta, let outside, let run { closer = closerPlan(beta: beta, external: outside, kind: betaKind, run: run) }
            days.append(TrainerComparisonDay(
                day: day, beta: beta, external: outside, externalKind: outside == nil ? nil : outsideKind,
                externalSummary: outside.map { summary(of: $0, kind: outsideKind) },
                betaSummary: betaKind == .off ? nil : beta.map(describe),
                match: match(beta: betaKind, external: outsideKind, betaMeters: beta?.totalMeters ?? 0, externalMeters: outside?.totalMeters ?? 0),
                run: run, closer: closer
            ))
        }
        return TrainerComparisonWeek(
            start: start, days: days,
            externalMeters: days.reduce(0.0) { $0 + ($1.external?.totalMeters ?? 0) },
            betaMeters: days.reduce(0.0) { $0 + ($1.beta?.totalMeters ?? 0) },
            externalQuality: days.filter { isQuality($0.externalKind) }.count,
            betaQuality: days.filter { isQuality($0.beta?.kind) }.count,
            sameKindDays: sameKind, comparedDays: days.count
        )
    }

    private static func summary(of external: TrainerExternalWorkout, kind: TrainerDayKind) -> String {
        let main = external.steps.first { $0.kind == .work || $0.kind == .steady }
        return describe(TrainerWorkout(
            day: external.day, kind: kind, title: external.name, totalMeters: external.totalMeters, steps: external.steps,
            paceLow: main?.paceLow, paceHigh: main?.paceHigh, rationale: ""
        ))
    }
}
