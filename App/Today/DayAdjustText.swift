import Foundation
import GarminAPI
import Insights
import Storage
import TrainingCore
import WorkoutAnalysis

enum DayAdjustText {
    private typealias C = TodayConstants

    static func shape(_ shape: PlannedWorkoutShape) -> DayAdjustShape {
        switch shape {
        case .continuous: .continuous
        case .intervals: .intervals
        case .long: .long
        }
    }

    static func input(
        plan: PlannedWorkout, score: Int?, forecast: [HourlyWeather], hour: Int, hotSessions: Int, heavyLegs: Bool
    ) -> DayAdjustInput {
        let weather = DayAdjust.closestIndex(to: hour, in: forecast.map(\.hour)).map { forecast[$0] }
        return DayAdjustInput(
            plan: plan, shape: shape(PlanText.shape(plan)), score: score, temperature: weather?.temperature,
            dewPoint: weather?.dewPoint, hotSessions: hotSessions, heavyLegs: heavyLegs, radiation: weather?.radiation
        )
    }

    static func usualHour(for plan: PlannedWorkout?, runs: [UsualHourRun], now: Date = .now) -> Int {
        UsualHour.hour(for: now, long: plan.map { PlanText.shape($0) == .long } ?? false, runs: runs, now: now, calendar: .current)
    }

    static func usualRuns(_ records: [ActivityRecord]) -> [UsualHourRun] {
        records.map { UsualHourRun(start: $0.start, meters: $0.distance ?? 0, seconds: $0.duration ?? 0) }
    }

    static func display(_ result: DayAdjustResult, plan: PlannedWorkout, hour: Int) -> DayAdjustDisplay {
        let shape = PlanText.shape(plan)
        switch result {
        case .none:
            return DayAdjustDisplay(steps: plan.steps, original: nil, notice: nil, fallback: nil)
        case .adjusted(let steps, let original, _, _, _):
            return DayAdjustDisplay(steps: steps, original: original, notice: notice(result, shape: shape, hour: hour), fallback: nil)
        case .swap(let reasons):
            let notice = DayAdjustNotice(title: C.planAdjustTitle, text: swap(reasons), chips: chips(reasons, hour: hour))
            return DayAdjustDisplay(steps: plan.steps, original: nil, notice: notice, fallback: nil)
        case .rest:
            return DayAdjustDisplay(steps: plan.steps, original: nil, notice: nil, fallback: C.planAdjustRest[shape])
        }
    }

    static func swap(_ reasons: [DayAdjustReason]) -> String {
        let words = ordered(reasons).compactMap { words(for: $0)?.morning }
        let limit = DayAdjustConstants.maximumSeconds
        return words.isEmpty
            ? String(format: C.dayAdjustSwapPlainFormat, limit)
            : String(format: C.dayAdjustSwapFormat, limit, list(words))
    }

    static func notice(_ result: DayAdjustResult, shape: PlannedWorkoutShape, hour: Int) -> DayAdjustNotice? {
        guard case .adjusted(_, _, let seconds, let reasons, _) = result else { return nil }
        let title = String(format: C.dayAdjustTitleFormat, C.planAdjustTitle, seconds, C.dayAdjustTitleTarget[shape] ?? "")
        let advice = C.dayAdjustAdvice[shape] ?? ""
        let words = ordered(reasons).compactMap { words(for: $0)?.body }
        let text = words.isEmpty
            ? String(format: C.dayAdjustBodyPlainFormat, advice)
            : String(format: C.dayAdjustBodyFormat, list(words), advice)
        return DayAdjustNotice(title: title, text: text, chips: chips(reasons, hour: hour))
    }

    static func chips(_ reasons: [DayAdjustReason], hour: Int) -> [String] {
        ordered(reasons).map { reason in
            switch reason {
            case .heat(let temperature, let dewPoint, let seconds):
                String(format: C.dayAdjustHeatChipFormat, Int(temperature.rounded()), Int(dewPoint.rounded()), hour, seconds)
            case .readiness(let score, let seconds): String(format: C.dayAdjustReadinessChipFormat, score, seconds)
            case .heavyLegs(let seconds): String(format: C.dayAdjustLegsChipFormat, seconds)
            case .noForecast: C.dayAdjustNoForecastChip
            }
        }
    }

    static func morning(_ result: DayAdjustResult, plan: PlannedWorkout) -> String? {
        guard case .adjusted(let steps, _, _, let reasons, _) = result,
              let lead = C.dayAdjustMorningLead[PlanText.shape(plan)],
              let range = firstActiveRange(steps) else { return nil }
        return morning(lead: lead, range: range, reasons: reasons)
    }

    static func trainerMorning(_ result: TrainerDayAdjustResult, plan: PlannedWorkout) -> String? {
        guard case .adjusted(let change) = result,
              let lead = C.dayAdjustMorningLead[PlanText.shape(plan)],
              let first = TrainerDayAdjust.activeRanges(change.workout).first else { return nil }
        return morning(lead: lead, range: range(fastest: first.low, slowest: first.high), reasons: change.reasons)
    }

    static func watchDisplay(_ watch: DayAdjustWatch, plan: PlannedWorkout) -> DayAdjustDisplay {
        let hour = watch.entries.hour
        switch watch.result {
        case .none: return display(.none, plan: plan, hour: hour)
        case .rest: return display(.rest, plan: plan, hour: hour)
        case .swap(let reasons): return display(.swap(reasons: reasons), plan: plan, hour: hour)
        case .adjusted(let change):
            let original = replacingPaces(plan.steps, with: change.original)
            let result = DayAdjustResult.adjusted(
                steps: plan.steps, original: original, seconds: change.seconds, reasons: change.reasons, shortened: change.shortened
            )
            return DayAdjustDisplay(
                steps: plan.steps, original: original, notice: notice(result, shape: PlanText.shape(plan), hour: hour), fallback: nil
            )
        }
    }

    static func replacingPaces(_ steps: [PlannedStep], with ranges: [TrainerPaceRange]) -> [PlannedStep] {
        var remaining = ranges[...]
        func replaced(_ step: PlannedStep) -> PlannedStep {
            var result = step
            if !step.children.isEmpty {
                result.children = step.children.map(replaced)
                return result
            }
            guard step.kind == .active, case .pace? = step.target, let range = remaining.popFirst() else { return step }
            result.target = .pace(fastest: range.low, slowest: range.high)
            return result
        }
        return steps.map(replaced)
    }

    private static func morning(lead: String, range: String, reasons: [DayAdjustReason]) -> String {
        let words = ordered(reasons).compactMap { words(for: $0)?.morning }
        return words.isEmpty
            ? String(format: C.dayAdjustMorningPlainFormat, lead, range)
            : String(format: C.dayAdjustMorningFormat, lead, range, list(words))
    }

    static func morningLine(
        plan: PlannedWorkout, score: Int?, forecast: [HourlyWeather], recent: [ActivityRecord], heavyLegs: Bool, showsAdvice: Bool = true
    ) -> String? {
        guard showsAdvice else { return nil }
        let hour = usualHour(for: plan, runs: usualRuns(recent))
        let input = input(
            plan: plan, score: score, forecast: forecast, hour: hour,
            hotSessions: ActivityRecord.hotSessions(before: .now, among: recent), heavyLegs: heavyLegs
        )
        return morning(DayAdjust.adjust(input), plan: plan)
    }

    static func pendingRun(_ plans: [PlannedWorkout], recent: [ActivityRecord], day: Day) -> PlannedWorkout? {
        let done = recent.filter { Day.today(now: $0.start) == day }.sorted { $0.start < $1.start }.map(\.displayTitle)
        return TodayWorkoutPicker.pending(plans, doneTitles: done).first
    }

    static func range(fastest: Double, slowest: Double) -> String {
        String(format: C.dayAdjustRangeFormat, WorkoutFormat.clock(fastest), WorkoutFormat.clock(slowest))
    }

    private static func firstActiveRange(_ steps: [PlannedStep]) -> String? {
        for step in steps.flatMap(\.flattened) where step.kind == .active {
            if case .pace(let fastest, let slowest)? = step.target { return range(fastest: fastest, slowest: slowest) }
        }
        return nil
    }

    private static func ordered(_ reasons: [DayAdjustReason]) -> [DayAdjustReason] {
        reasons.sorted { rank($0) < rank($1) }
    }

    private static func rank(_ reason: DayAdjustReason) -> Int {
        switch reason {
        case .heat: 0
        case .readiness: 1
        case .heavyLegs: 2
        case .noForecast: 3
        }
    }

    private static func words(for reason: DayAdjustReason) -> (body: String, morning: String)? {
        switch reason {
        case .heat: C.dayAdjustHeatWords
        case .readiness: C.dayAdjustReadinessWords
        case .heavyLegs: C.dayAdjustLegsWords
        case .noForecast: nil
        }
    }

    private static func list(_ words: [String]) -> String {
        guard let last = words.last, words.count > 1 else { return words.first ?? "" }
        return words.dropLast().joined(separator: C.dayAdjustListSeparator) + C.dayAdjustListLastSeparator + last
    }
}
