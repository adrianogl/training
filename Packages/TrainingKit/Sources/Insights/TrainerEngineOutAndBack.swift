import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    static func runUnit(_ week: TrainerWeek) -> Double {
        week.outAndBack ? C.outAndBackUnitMeters : C.metersPerKilometer
    }

    static func roundRun(_ meters: Double, unit: Double) -> Double {
        (meters / unit).rounded() * unit
    }

    static func floorRun(_ meters: Double, unit: Double) -> Double {
        (meters / unit).rounded(.down) * unit
    }

    static func ceilRun(_ meters: Double, unit: Double) -> Double {
        (meters / unit).rounded(.up) * unit
    }

    static func evenLongs(_ weeks: [TrainerWeek], paces: TrainerPaces, firstCap: Double? = nil) -> [TrainerWeek] {
        weeks.enumerated().map { index, week in
            guard week.outAndBack else { return week }
            if index == 0, let firstCap, ceilRun(week.longMeters, unit: C.outAndBackUnitMeters) > firstCap {
                var result = week
                result.longMeters = max(floorRun(week.longMeters, unit: C.outAndBackUnitMeters), min(C.minimumLongMeters, week.longMeters))
                return result
            }
            let up = ceilRun(week.longMeters, unit: C.outAndBackUnitMeters)
            let down = max(floorRun(week.longMeters, unit: C.outAndBackUnitMeters), C.minimumLongMeters)
            let ceiling = min(
                floorKilometers(C.longMaximumSeconds / paces.long * C.metersPerKilometer),
                floorKilometers(week.skeletonMeters * C.longestWeekShare)
            )
            var result = week
            result.longMeters = up <= max(ceiling, week.longMeters) ? up : down
            return result
        }
    }

    static func turned(_ session: TrainerQualitySession) -> TrainerQualitySession {
        guard let best = turnGap(ends: repEnds(session), total: qualityMeters(session)) else { return session }
        var result = session
        result.turnAfterRep = best.rep
        result.warmupExtraMeters = max(best.gap, 0)
        result.tailMeters = max(-best.gap, 0)
        return result
    }

    static func turnGap(ends: [Double], total: Double) -> (rep: Int, gap: Double)? {
        ends.enumerated().compactMap { index, end -> (rep: Int, gap: Double)? in
            let gap = total - 2 * end
            return abs(gap) <= C.outAndBackTailMaximumMeters ? (index + 1, gap) : nil
        }
        .min { (abs($0.gap), $0.gap) < (abs($1.gap), $1.gap) }
    }

    static func hasTurn(_ workout: TrainerWorkout) -> Bool {
        workout.steps.contains { $0.turnsAfter == true }
    }

    static func unturnedSteps(_ steps: [TrainerStep]) -> [TrainerStep] {
        guard steps.contains(where: { $0.turnsAfter == true }) else { return steps }
        var merged: [TrainerStep] = []
        for var step in expandedSteps(steps) {
            step.turnsAfter = nil
            if let last = merged.last, last.kind == step.kind, step.kind != .recovery, last.restSeconds == nil, step.restSeconds == nil,
               last.paceLow == step.paceLow, last.paceHigh == step.paceHigh, last.method == step.method {
                merged[merged.count - 1].meters += step.meters
            } else {
                merged.append(step)
            }
        }
        return groupedSteps(merged)
    }

    static func returned(_ workout: TrainerWorkout) -> TrainerWorkout {
        var result = workout
        result.steps = unturnedSteps(workout.steps)
        guard workout.kind == .threshold || workout.kind == .vo2max else {
            return withTurn(result)
        }
        var flat = expandedSteps(result.steps)
        if flat.last?.kind == .cooldown { flat.removeLast() }
        if let warmup = flat.firstIndex(where: { $0.kind == .warmup }) { flat[warmup].meters = C.warmupMeters }
        var distance = 0.0
        var ends: [Double] = []
        for step in flat {
            distance += step.meters
            if step.isMainWork { ends.append(distance) }
        }
        guard let best = turnGap(ends: ends, total: distance) else {
            result.steps = groupedSteps(flat)
            result.totalMeters = distance
            return withTurn(result)
        }
        var seen = 0
        if let index = flat.firstIndex(where: { step in
            guard step.isMainWork else { return false }
            seen += 1
            return seen == best.rep
        }) { flat[index].turnsAfter = true }
        if best.gap > 0, let warmup = flat.firstIndex(where: { $0.kind == .warmup }) { flat[warmup].meters += best.gap }
        if best.gap < 0, let easy = flat.first(where: { $0.kind == .warmup }) {
            flat.append(TrainerStep(kind: .cooldown, meters: -best.gap, paceLow: easy.paceLow, paceHigh: easy.paceHigh))
        }
        result.steps = groupedSteps(flat)
        result.totalMeters = flat.reduce(0.0) { $0 + $1.meters }
        return result
    }

    static func repEnds(_ session: TrainerQualitySession) -> [Double] {
        var distance = C.warmupMeters + (session.closing ? stridesMeters : 0)
        var ends: [Double] = []
        let blocks = session.variant == .hills ? Array(session.blocks.prefix(1)) : session.blocks
        for block in blocks {
            for index in 0..<block.repeats {
                distance += block.meters
                ends.append(distance)
                if session.variant == .hills && index < block.repeats - 1 { distance += block.meters }
            }
        }
        return ends
    }

    static func turnedSteps(_ steps: [TrainerStep], session: TrainerQualitySession, paces: TrainerPaces) -> [TrainerStep] {
        guard let rep = session.turnAfterRep else { return steps }
        var flat = expandedSteps(steps)
        var seen = 0
        guard let index = flat.firstIndex(where: { step in
            guard step.isMainWork else { return false }
            seen += 1
            return seen == rep
        }) else { return steps }
        flat[index].turnsAfter = true
        if session.warmupExtraMeters > 0, let warmup = flat.firstIndex(where: { $0.kind == .warmup }) {
            flat[warmup].meters += session.warmupExtraMeters
        }
        if session.tailMeters > 0 {
            let easy = band(paces.easy, C.easyBand)
            flat.append(TrainerStep(kind: .cooldown, meters: session.tailMeters, paceLow: easy.low, paceHigh: easy.high))
        }
        return groupedSteps(flat)
    }

    static func withTurn(_ workout: TrainerWorkout) -> TrainerWorkout {
        guard workout.kind != .off, workout.kind != .race, !workout.steps.contains(where: { $0.turnsAfter == true }) else { return workout }
        var flat = expandedSteps(workout.steps)
        let half = flat.reduce(0.0) { $0 + $1.meters } / 2
        var distance = 0.0
        for index in flat.indices {
            let end = distance + flat[index].meters
            if abs(end - half) < C.outAndBackToleranceMeters {
                flat[index].turnsAfter = true
                break
            }
            if end > half {
                guard flat[index].restSeconds == nil else { return workout }
                var first = flat[index]
                first.meters = half - distance
                first.turnsAfter = true
                var second = flat[index]
                second.meters = end - half
                flat.replaceSubrange(index...index, with: [first, second])
                break
            }
            distance = end
        }
        guard flat.contains(where: { $0.turnsAfter == true }) else { return workout }
        var result = workout
        result.steps = groupedSteps(flat)
        return result
    }

    static func expandedSteps(_ steps: [TrainerStep]) -> [TrainerStep] {
        var flat: [TrainerStep] = []
        var index = 0
        while index < steps.count {
            guard steps[index].repeats > 0 else {
                index += 1
                continue
            }
            let step = single(steps[index])
            let next = index + 1 < steps.count ? steps[index + 1] : nil
            if steps[index].repeats > 1, let next, next.kind == .recovery,
               next.repeats == steps[index].repeats - 1 || next.isStrides && next.repeats == steps[index].repeats {
                for repeatIndex in 0..<steps[index].repeats {
                    flat.append(step)
                    if repeatIndex < next.repeats { flat.append(single(next)) }
                }
                index += 2
            } else {
                flat += Array(repeating: step, count: max(steps[index].repeats, 1))
                index += 1
            }
        }
        return flat
    }

    static func groupedSteps(_ flat: [TrainerStep]) -> [TrainerStep] {
        var result: [TrainerStep] = []
        var index = 0
        while index < flat.count {
            let first = flat[index]
            guard first.kind == .work, first.turnsAfter != true else {
                result.append(first)
                index += 1
                continue
            }
            var count = 1
            var recovery: TrainerStep?
            var cursor = index + 1
            while cursor + 1 < flat.count, flat[cursor].kind == .recovery, recovery.map({ $0 == flat[cursor] }) ?? true,
                  sameRep(flat[cursor + 1], first) {
                recovery = flat[cursor]
                count += 1
                cursor += 2
                if flat[cursor - 1].turnsAfter == true { break }
            }
            guard count > 1, var rest = recovery else {
                result.append(first)
                index += 1
                continue
            }
            var work = first
            work.repeats = count
            work.turnsAfter = flat[cursor - 1].turnsAfter
            rest.repeats = count - 1
            if work.isStrides, cursor < flat.count, flat[cursor] == recovery {
                rest.repeats = count
                cursor += 1
            }
            result += [work, rest]
            index = cursor
        }
        return result
    }

    private static func single(_ step: TrainerStep) -> TrainerStep {
        var result = step
        result.repeats = 1
        return result
    }

    private static func sameRep(_ lhs: TrainerStep, _ rhs: TrainerStep) -> Bool {
        var left = lhs
        var right = rhs
        left.turnsAfter = nil
        right.turnsAfter = nil
        return left == right
    }
}
