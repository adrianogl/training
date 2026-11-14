import Foundation
import GarminAPI
import TrainingCore
import WorkoutAnalysis

enum PlannedBriefingBuilder {
    private typealias C = PlannedBriefingConstants

    static func briefing(_ input: BriefingInput) -> PlannedBriefing {
        let plan = input.plan
        let kind = kind(plan)
        let target = paceTarget(plan)
        let kilometers = (plan.estimatedMeters ?? 0) / WorkoutConstants.metersPerKilometer
        let heart = heartRange(input.similar)
        let maxHeart = average(input.similar.compactMap(\.maxHeartRate))
        return PlannedBriefing(
            kind: kind,
            stats: stats(plan, target: target, kilometers: kilometers, similar: input.similar),
            summary: summary(kind, plan: plan, target: target, kilometers: kilometers, input: input),
            tags: tags(input),
            phases: phases(kind, plan: plan, target: target, kilometers: kilometers, heart: heart),
            reps: kind == .intervals ? reps(plan, target: target, maxHeart: maxHeart) : [],
            repsNote: kind == .intervals && target != nil ? C.repsNote : nil,
            expectations: expectations(input.similar, heart: heart),
            expectationNote: input.similar.isEmpty ? nil : expectationNote(kind),
            attention: attention(kind, input: input, kilometers: kilometers),
            planB: planB(kind, plan: plan, target: target, kilometers: kilometers),
            previous: Array(input.similar.prefix(C.similarLimit)),
            previousNote: previousNote(input.similar),
            carry: carry(kind, plan: plan),
            raceNote: raceNote(kind, kilometers: kilometers, race: input.race),
            bestHours: bestHours(input.weather),
            bestHoursNote: bestHoursNote(input.weather),
            course: input.course,
            comparison: comparison(input.completed, plan: plan, target: target, heart: heart),
            comparisonNote: comparisonNote(input.completed, plan: plan, target: target, heart: heart),
            watchTip: watchTip(kind, plan: plan, target: target, heart: heart, weather: input.weather)
        )
    }

    static func kind(_ plan: PlannedWorkout) -> PlannedKind {
        let repeats = plan.steps.contains { step in
            step.repeats > 1 && step.children.contains { $0.kind == .active || $0.kind == .other }
        }
        if repeats { return .intervals }
        if (plan.estimatedMeters ?? 0) >= C.longMeters || (plan.estimatedSeconds ?? 0) >= C.longSeconds { return .long }
        let title = plan.title.lowercased()
        let zoneHigh = plan.steps.flatMap(\.flattened).contains { step in
            if case .zone(let zone) = step.target { return zone >= C.tempoZone }
            return false
        }
        if zoneHigh || C.tempoWords.contains(where: title.contains) { return .tempo }
        return .easy
    }

    static func similarityKey(_ title: String) -> String {
        title.lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "-" })
            .map(String.init)
            .filter { word in !word.contains(where: \.isNumber) && !C.ignoredTitleWords.contains(word) }
            .joined(separator: " ")
    }

    static func paceTarget(_ plan: PlannedWorkout) -> (fast: Double, slow: Double)? {
        for step in plan.steps.flatMap(\.flattened) where step.kind == .active || step.kind == .other {
            if case .pace(let fastest, let slowest) = step.target { return (fastest, slowest) }
        }
        return nil
    }

    private static func stats(_ plan: PlannedWorkout, target: (fast: Double, slow: Double)?, kilometers: Double, similar: [SimilarRun]) -> [BriefingStat] {
        var stats: [BriefingStat] = []
        if kilometers > 0 { stats.append(BriefingStat(value: "\(km(kilometers)) km", label: C.statDistance)) }
        stats.append(BriefingStat(value: target.map { "\(clock($0.fast))–\(clock($0.slow))" } ?? C.freePace, label: C.statPace))
        if let target, kilometers > 0, kind(plan) != .intervals {
            stats.append(BriefingStat(value: "\(duration(kilometers * target.fast))–\(duration(kilometers * target.slow))", label: C.statTime))
        } else if let seconds = plan.estimatedSeconds {
            stats.append(BriefingStat(value: "~\(duration(seconds))", label: C.statTime))
        }
        if let load = average(similar.compactMap(\.load)) {
            stats.append(BriefingStat(value: "~\(Int(load.rounded()))", label: C.statLoad))
        }
        return stats
    }

    private static func summary(_ kind: PlannedKind, plan: PlannedWorkout, target: (fast: Double, slow: Double)?, kilometers: Double, input: BriefingInput) -> String {
        var text: String
        switch kind {
        case .long:
            text = C.summaryLong
            if let race = input.race, kilometers > race.longestKilometers {
                text += String(format: C.summaryLongestFormat, km(kilometers))
            }
        case .intervals:
            let group = plan.steps.first { $0.repeats > 1 && !$0.children.isEmpty }
            let size = group?.children.first { $0.kind == .active || $0.kind == .other }.flatMap(sizeText) ?? ""
            text = String(format: C.summaryIntervalsFormat, group?.repeats ?? 0, size, target.map { clock(mid($0)) } ?? "—")
        case .tempo:
            text = String(format: C.summaryTempoFormat, target.map { clock(mid($0)) } ?? "—")
        case .easy:
            text = C.summaryEasy
        }
        if let readiness = input.readiness {
            let format = readiness >= C.readinessGood ? C.summaryReadyFormat : readiness >= C.readinessLow ? C.summaryCarefulFormat : C.summaryLowFormat
            text += String(format: format, readiness)
        }
        return text
    }

    private static func tags(_ input: BriefingInput) -> [BriefingTag] {
        var tags: [BriefingTag] = []
        if let readiness = input.readiness {
            let tone: BriefingTone = readiness >= C.readinessGood ? .good : readiness >= C.readinessLow ? .warn : .bad
            tags.append(BriefingTag(text: String(format: C.tagReadinessFormat, readiness), tone: tone))
        }
        if let race = input.race {
            tags.append(BriefingTag(text: String(format: C.tagRaceFormat, race.name, race.days), tone: .info))
        }
        if let hot = hotHour(input.weather) {
            tags.append(BriefingTag(text: String(format: C.tagHeatFormat, Int(hot.temperature.rounded()), hot.hour), tone: .warn))
        }
        return tags
    }

    private static func phases(_ kind: PlannedKind, plan: PlannedWorkout, target: (fast: Double, slow: Double)?, kilometers: Double, heart: (low: Double, high: Double)?) -> [BriefingPhase] {
        let single = plan.steps.count == 1 && plan.steps[0].children.isEmpty
        guard kind != .intervals, single, let target, kilometers >= 5 else {
            return plan.steps.map { step in
                let name = step.children.isEmpty
                    ? TodayConstants.planStepNames[step.kind] ?? ""
                    : String(format: TodayConstants.planRepeatFormat, step.repeats)
                let detail = step.children.isEmpty ? PlanText.detail(step) : step.children.map(PlanText.detail).joined(separator: " + ")
                return BriefingPhase(when: name, length: nil, title: detail, detail: "")
            }
        }
        let total = Int(kilometers.rounded())
        let closing = max(2, Int((kilometers * C.closingShare).rounded()))
        let blockEnd = max(3, total - closing)
        var entry = String(format: C.phaseEntryFormat, clock(target.slow + C.entrySlowerSeconds), clock(target.slow))
        if let heart { entry += String(format: C.phaseEntryHeartFormat, Int((heart.low - C.heartMargin).rounded())) }
        var block = String(format: C.phaseBlockFormat, clock(mid(target)))
        if let heart { block += String(format: C.phaseBlockHeartFormat, Int(heart.high.rounded()), clock(target.slow)) }
        var close = C.phaseClose
        if let heart { close += String(format: C.phaseCloseHeartFormat, Int((heart.high + C.heartMargin).rounded()), max(blockEnd, total - 2)) }
        return [
            BriefingPhase(when: C.phaseEntryWhen, length: minutes(2 * target.slow), title: C.phaseEntryTitle, detail: entry),
            BriefingPhase(
                when: String(format: C.phaseBlockWhenFormat, blockEnd),
                length: minutes(Double(blockEnd - 2) * mid(target)),
                title: String(format: C.phaseBlockTitleFormat, clock(target.fast), clock(target.slow)),
                detail: block
            ),
            BriefingPhase(when: String(format: C.phaseCloseWhenFormat, blockEnd, total), length: minutes(Double(total - blockEnd) * mid(target)), title: C.phaseCloseTitle, detail: close),
        ]
    }

    private static func reps(_ plan: PlannedWorkout, target: (fast: Double, slow: Double)?, maxHeart: Double?) -> [BriefingRep] {
        guard let target, let group = plan.steps.first(where: { $0.repeats > 1 && !$0.children.isEmpty }) else { return [] }
        let count = group.repeats
        let middle = mid(target)
        let early = middle + (target.slow - middle) / 2
        let late = middle - (middle - target.fast) / 2
        let heart = { (offset: Double) in maxHeart.map { String(format: C.repsHeartFormat, Int(($0 - offset).rounded())) } }
        guard count >= 6 else {
            let half = count / 2
            return [
                BriefingRep(label: label(1, half), pace: clock(early), heartRate: heart(6), note: C.repsEarly),
                BriefingRep(label: label(half + 1, count), pace: clock(late), heartRate: heart(0), note: C.repsLate),
            ]
        }
        return [
            BriefingRep(label: label(1, 2), pace: clock(early), heartRate: heart(8), note: C.repsEarly),
            BriefingRep(label: label(3, count - 3), pace: clock(middle), heartRate: heart(4), note: C.repsMiddle),
            BriefingRep(label: label(count - 2, count), pace: clock(late), heartRate: heart(0), note: C.repsLate),
        ]
    }

    private static func expectations(_ similar: [SimilarRun], heart: (low: Double, high: Double)?) -> [BriefingStat] {
        var stats: [BriefingStat] = []
        if let heart { stats.append(BriefingStat(value: "\(Int(heart.low.rounded()))–\(Int(heart.high.rounded()))", label: C.expectHeart)) }
        let effects = similar.compactMap(\.aerobicEffect)
        if let low = effects.min(), let high = effects.max() {
            stats.append(BriefingStat(value: low == high ? decimal(low) : "\(decimal(low))–\(decimal(high))", label: C.expectEffect))
        }
        if let effect = average(effects), let hours = C.recoveryHours.last(where: { effect >= $0.effect })?.hours ?? C.recoveryHours.first?.hours {
            stats.append(BriefingStat(value: hours, label: C.expectRecovery))
        }
        return stats
    }

    private static func expectationNote(_ kind: PlannedKind) -> String {
        switch kind {
        case .long, .tempo: C.expectNoteLong
        case .intervals: C.expectNoteIntervals
        case .easy: C.expectNoteDefault
        }
    }

    private static func attention(_ kind: PlannedKind, input: BriefingInput, kilometers: Double) -> [BriefingItem] {
        var items: [BriefingItem] = []
        if let hot = hotHour(input.weather) {
            items.append(BriefingItem(title: C.attentionHeatTitle, detail: String(format: C.attentionHeatFormat, Int(hot.temperature.rounded()), hot.hour, C.heatSlowdown), tone: .warn))
        }
        if let fade = input.similar.first?.fadeSecondsPerKm, fade >= C.fadeSignificant {
            items.append(BriefingItem(title: C.attentionFadeTitle, detail: String(format: C.attentionFadeFormat, Int(fade.rounded())), tone: .warn))
        }
        if input.weekPlannedKm > 0 {
            let projected = km(input.weekPlannedKm)
            let detail = input.weekGoalKm.map { String(format: C.attentionWeekFormat, projected, km($0)) } ?? String(format: C.attentionWeekNoGoalFormat, projected)
            items.append(BriefingItem(title: C.attentionWeekTitle, detail: detail, tone: .info))
        }
        if let days = input.daysSinceHard, kind != .easy {
            let short = days < 2
            items.append(BriefingItem(
                title: C.attentionRecoveryTitle,
                detail: String(format: short ? C.attentionRecoveryShortFormat : C.attentionRecoveryGoodFormat, days),
                tone: short ? .warn : .good
            ))
        }
        if let readiness = input.readiness, readiness < C.readinessLow {
            items.insert(BriefingItem(title: C.attentionReadinessTitle, detail: String(format: C.attentionReadinessFormat, readiness), tone: .bad), at: 0)
        }
        return items
    }

    private static func planB(_ kind: PlannedKind, plan: PlannedWorkout, target: (fast: Double, slow: Double)?, kilometers: Double) -> [BriefingItem] {
        let reduced: String
        switch kind {
        case .long:
            let easy = (target?.slow ?? 300) + C.reducedEasyPaceExtra
            reduced = String(format: C.planBLongFormat, km((kilometers * C.reducedLongShare).rounded()), clock(easy))
        case .intervals:
            let count = plan.steps.first { $0.repeats > 1 }?.repeats ?? 0
            reduced = String(format: C.planBIntervalsFormat, max(1, Int((Double(count) * C.reducedRepsShare).rounded())), count)
        case .tempo, .easy:
            reduced = C.planBDefault
        }
        return [
            BriefingItem(title: String(format: C.planBLowTitleFormat, C.readinessLow), detail: reduced, tone: .warn),
            BriefingItem(title: C.planBPainTitle, detail: C.planBPain, tone: .bad),
        ]
    }

    private static func previousNote(_ similar: [SimilarRun]) -> String? {
        guard let latest = similar.first else { return nil }
        if let fade = latest.fadeSecondsPerKm, fade >= C.fadeSignificant {
            return String(format: C.previousNoteFadeFormat, shortDate(latest.day), Int(fade.rounded()))
        }
        return C.previousNoteSteady
    }

    private static func carry(_ kind: PlannedKind, plan: PlannedWorkout) -> [String] {
        let minutes = (plan.estimatedSeconds ?? 0) / 60
        var items: [String] = []
        if minutes >= C.hydrationMinutes { items.append(C.carryHydration) }
        if minutes >= C.gelMinutes { items.append(String(format: C.carryGelFormat, max(1, Int(minutes / C.gelEveryMinutes)))) }
        items.append(C.carryWatch)
        if kind == .long { items.append(C.carryShoes) }
        return items
    }

    private static func raceNote(_ kind: PlannedKind, kilometers: Double, race: PlannedRaceContext?) -> String? {
        guard kind == .long, let race, kilometers > race.longestKilometers else { return nil }
        if kilometers >= race.longTargetKilometers, race.longestKilometers < race.longTargetKilometers {
            return String(format: C.raceLongDoneFormat, race.name, km(kilometers), km(race.longTargetKilometers))
        }
        return String(format: C.raceLongProgressFormat, race.name, km(race.longTargetKilometers))
    }

    private static func bestHours(_ weather: [HourlyWeather]) -> [HourlyWeather] {
        weather.filter { C.morningHours.contains($0.hour) }.sorted { $0.hour < $1.hour }
    }

    static func coolest(_ weather: [HourlyWeather]) -> [HourlyWeather] {
        let morning = bestHours(weather)
        guard morning.count >= C.bestHoursCount else { return morning }
        let windows = (0...(morning.count - C.bestHoursCount)).map { Array(morning[$0..<($0 + C.bestHoursCount)]) }
        return windows.min { $0.map(\.temperature).reduce(0, +) < $1.map(\.temperature).reduce(0, +) } ?? []
    }

    private static func bestHoursNote(_ weather: [HourlyWeather]) -> String? {
        let best = coolest(weather)
        guard let first = best.first else { return nil }
        guard let hot = hotHour(weather) else { return C.bestHoursCool }
        return String(format: C.bestHoursFormat, first.hour, Int(first.temperature.rounded()), hot.hour, C.heatSlowdown)
    }

    private static func hotHour(_ weather: [HourlyWeather]) -> HourlyWeather? {
        weather.first { $0.hour == C.plannedHour + 1 && $0.temperature >= C.hotTemperature }
            ?? weather.first { $0.hour == C.plannedHour && $0.temperature >= C.hotTemperature }
    }

    private static func comparison(_ done: CompletedCheck?, plan: PlannedWorkout, target: (fast: Double, slow: Double)?, heart: (low: Double, high: Double)?) -> [BriefingComparison] {
        guard let done else { return [] }
        var rows: [BriefingComparison] = []
        if let meters = plan.estimatedMeters, meters > 0 {
            let planned = meters / WorkoutConstants.metersPerKilometer
            rows.append(BriefingComparison(label: C.compareDistance, planned: "\(km(planned)) km", done: "\(km(done.kilometers)) km", ok: done.kilometers >= planned * 0.9))
        }
        if let target, let pace = done.paceSecondsPerKm {
            rows.append(BriefingComparison(label: C.comparePace, planned: "\(clock(target.fast))–\(clock(target.slow))", done: clock(pace), ok: pace >= target.fast - 3 && pace <= target.slow + 3))
        }
        if let heart, let average = done.averageHeartRate {
            rows.append(BriefingComparison(label: C.compareHeart, planned: "\(Int(heart.low.rounded()))–\(Int(heart.high.rounded()))", done: "\(Int(average.rounded()))", ok: average <= heart.high + 3))
        }
        if let fade = done.fadeSecondsPerKm {
            rows.append(BriefingComparison(label: C.compareFade, planned: C.compareSteady, done: String(format: C.compareFadeFormat, Int(max(0, fade).rounded())), ok: fade < C.fadeSignificant))
        }
        return rows
    }

    private static func comparisonNote(_ done: CompletedCheck?, plan: PlannedWorkout, target: (fast: Double, slow: Double)?, heart: (low: Double, high: Double)?) -> String? {
        let rows = comparison(done, plan: plan, target: target, heart: heart)
        guard !rows.isEmpty else { return nil }
        return rows.allSatisfy(\.ok) ? C.compareDoneNote : C.comparePartialNote
    }

    private static func watchTip(_ kind: PlannedKind, plan: PlannedWorkout, target: (fast: Double, slow: Double)?, heart: (low: Double, high: Double)?, weather: [HourlyWeather]) -> String? {
        let text: String?
        if let hot = hotHour(weather) {
            text = String(format: C.watchHeatFormat, Int(hot.temperature.rounded()), hot.hour)
        } else if let heart, let target {
            let minutes = (plan.estimatedSeconds ?? 0) / 60
            let extra = minutes >= C.gelMinutes
                ? String(format: C.watchGel, max(1, Int((C.gelEveryMinutes * 60 / mid(target)).rounded())))
                : String(format: C.watchPaceFormat, clock(mid(target)))
            text = String(format: C.watchHeartFormat, Int(heart.high.rounded()), extra)
        } else {
            text = target.map { String(format: C.watchPaceFormat, clock(mid($0))) }
        }
        return text.map { String($0.prefix(C.watchTipLength)) }
    }

    private static func heartRange(_ similar: [SimilarRun]) -> (low: Double, high: Double)? {
        let values = similar.compactMap(\.averageHeartRate)
        guard let low = values.min(), let high = values.max() else { return nil }
        return low == high ? (low - 3, high + 3) : (low, high)
    }

    private static func label(_ first: Int, _ last: Int) -> String {
        if first == last { return String(format: C.repsLabelSingle, first) }
        if last == first + 1 { return String(format: C.repsLabelPair, first, last) }
        return String(format: C.repsLabelRange, first, last)
    }

    private static func sizeText(_ step: PlannedStep) -> String? {
        if let meters = step.meters {
            return meters < 3_000 ? "\(Int(meters.rounded())) m" : "\(km(meters / WorkoutConstants.metersPerKilometer)) km"
        }
        return step.seconds.map { "\(Int(($0 / 60).rounded())) min" }
    }

    private static func mid(_ target: (fast: Double, slow: Double)) -> Double { (target.fast + target.slow) / 2 }
    private static func average(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
    private static func clock(_ seconds: Double) -> String { WorkoutFormat.clock(seconds) }
    private static func km(_ value: Double) -> String { TodayText.decimal(value, fractionDigits: value.rounded() == value ? 0 : 1) }
    private static func decimal(_ value: Double) -> String { TodayText.decimal(value, fractionDigits: 1) }
    private static func minutes(_ seconds: Double) -> String { String(format: C.lengthMinutesFormat, Int((seconds / 60).rounded())) }
    private static func shortDate(_ day: Day) -> String { day.chartDate.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale)) }

    private static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        return hours > 0 ? "\(hours)h\(String(format: "%02d", minutes))" : "\(minutes) min"
    }
}
