import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static func normalWeeklyMeters(history: TrainerHistory, today: Day, plan: TrainerPlan?) -> TrainerNormalVolume {
        let starts = (1...C.normalWindowWeeks).map { today.weekStart.adding(days: -C.daysPerWeek * $0) }.reversed()
        var excluded: [TrainerExcludedWeek] = []
        var kept: [(start: Day, meters: Double)] = []
        for start in starts {
            if let reason = plannedReduction(start, plan: plan) {
                excluded.append(TrainerExcludedWeek(start: start, reason: reason))
            } else {
                let meters = history.runs.filter { $0.day.weekStart == start }.reduce(0.0) { $0 + $1.meters }
                kept.append((start, meters))
            }
        }
        let sorted = kept.map(\.meters).sorted()
        let median = sorted.isEmpty ? 0 : sorted[(sorted.count - 1) / 2]
        let low = kept.filter { $0.meters <= 0 || $0.meters < median * C.normalLowShare }
        excluded += low.map { TrainerExcludedWeek(start: $0.start, reason: .low) }
        let normal = kept.filter { $0.meters > 0 && $0.meters >= median * C.normalLowShare }
        let mean = normal.isEmpty ? 0 : normal.reduce(0.0) { $0 + $1.meters } / Double(normal.count)
        guard normal.count >= C.normalMinimumWeeks, mean > 0 else {
            return TrainerNormalVolume(meters: averageWeeklyMeters(history: history, today: today), excluded: [], fromNormalWeeks: false)
        }
        return TrainerNormalVolume(meters: roundKilometers(mean), excluded: excluded.sorted { $0.start < $1.start }, fromNormalWeeks: true)
    }

    public static func volumeSuggestion(
        history: TrainerHistory, today: Day, plan: TrainerPlan?, review: TrainerCycleReview?, structure: [Int: TrainerDayKind],
        paces: TrainerPaces, target: TrainerTarget
    ) -> TrainerVolumeSuggestion {
        let base = normalWeeklyMeters(history: history, today: today, plan: plan)
        if let review {
            return TrainerVolumeSuggestion(
                startMeters: review.suggestedStartMeters, peakMeters: review.suggestedPeakMeters, limit: .cycle(review.verdict), base: base
            )
        }
        let start = base.meters
        var peak = defaultPeak(from: start)
        var limit = TrainerVolumeLimit.growth
        let comfortable = floorKilometers(volumeRange(structure: structure, paces: paces, target: target).comfortable)
        if comfortable < peak {
            peak = max(comfortable, start)
            limit = .comfortable(runs: structure.values.filter { $0 != .off && $0 != .race }.count)
        }
        if let date = target.date, date >= today {
            let weeks = today.weekStart.days(until: date.weekStart) / C.daysPerWeek + 1
            let taper = (target.distanceMeters ?? .infinity) <= C.shortRaceMeters ? C.shortRaceTaperWeeks : C.taperWeeks
            let general = max(0, weeks - blockWeeks(for: target))
            let available = max(weeks - taper - general, 0)
            var reachable = peak
            while reachable > start, weeksToPeak(startMeters: start, peakMeters: reachable) > available {
                reachable -= C.metersPerKilometer
            }
            if reachable < peak {
                peak = reachable
                limit = .deadline(weeks: available)
            }
        }
        return TrainerVolumeSuggestion(startMeters: start, peakMeters: max(peak, start), limit: limit, base: base)
    }

    private static func plannedReduction(_ start: Day, plan: TrainerPlan?) -> TrainerExcludedWeekReason? {
        guard let plan else { return nil }
        if let race = plan.target.date, race.weekStart == start { return .race }
        if plan.lightWeeks.contains(start) { return .light }
        guard let week = plan.weeks.first(where: { $0.start == start }) else { return nil }
        if week.phase == .taper { return .taper }
        if week.isRecovery || week.lightKind != nil || week.calm { return .light }
        return nil
    }
}
