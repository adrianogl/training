import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    public static func suggestedStructure(
        _ preference: TrainerDayPreference
    ) -> [Int: TrainerDayKind] {
        let long = preference.longDay
        let free = (1...C.daysPerWeek).filter { $0 != long && !preference.offDays.contains($0) }
        let runs = min(max(preference.runs, TrainerDayPreference.runsRange.lowerBound), TrainerDayPreference.runsRange.upperBound)
        let count = min(runs - 1, free.count)
        let qualityCount = min(count + 1 > C.singleQualityRuns ? 2 : 1, count)
        var best: (cost: Int, runs: [Int], quality: [Int])?
        for runDays in combinations(free, count) {
            for quality in combinations(runDays, qualityCount) {
                let cost = suggestionCost(runs: runDays, quality: quality, long: long)
                if best.map({ cost < $0.cost }) ?? true { best = (cost, runDays, quality) }
            }
        }
        var structure = Dictionary(uniqueKeysWithValues: (1...C.daysPerWeek).map { ($0, TrainerDayKind.off) })
        structure[long] = .long
        guard let best else { return structure }
        let easy = best.runs.filter { !best.quality.contains($0) }
        for day in easy { structure[day] = .easy }
        let ordered = best.quality.sorted { offset($0, from: long) < offset($1, from: long) }
        for (index, day) in ordered.enumerated() { structure[day] = index == 0 ? .threshold : .vo2max }
        if preference.optional, let day = C.optionalOffsets.lazy.map({ shifted(long, by: $0) }).first(where: easy.contains) {
            structure[day] = .optionalEasy
        }
        return structure
    }

    public static func dayWarnings(
        structure: [Int: TrainerDayKind], strength: [TrainerStrengthSession], peakMeters: Double, paces: TrainerPaces,
        target: TrainerTarget
    ) -> [TrainerDayWarning] {
        let kinds = (1...C.daysPerWeek).map { structure[$0] ?? .off }
        func kind(_ day: Int) -> TrainerDayKind { kinds[day - 1] }
        var warnings: [TrainerDayWarning] = []
        for day in 1...C.daysPerWeek {
            let next = shifted(day, by: 1)
            guard C.strongKinds.contains(kind(day)), C.strongKinds.contains(kind(next)) else { continue }
            let text: String
            if kind(next) == .long && C.qualityKinds.contains(kind(day)) {
                text = T.eveOfLongWarning(kind(day))
            } else if kind(day) == .long && C.qualityKinds.contains(kind(next)) {
                text = T.afterLongWarning(kind(next))
            } else {
                text = T.strongInARowWarning(kind(day), kind(next))
            }
            warnings.append(TrainerDayWarning(days: [day, next], text: text))
        }
        let legDays = legStrengthDays(strength)
        for day in 1...C.daysPerWeek where C.qualityKinds.contains(kind(day)) {
            let before = shifted(day, by: -1)
            guard legDays.contains(before) else { continue }
            warnings.append(TrainerDayWarning(days: [day], text: T.afterLegStrengthWarning(kind(day), weekday: before), isSoft: true))
        }
        if !kinds.contains(.off) { warnings.append(TrainerDayWarning(days: [], text: T.noRestWarning)) }
        let peak = roundKilometers(peakMeters)
        let possible = possiblePeak(structure: structure, peakMeters: peak, paces: paces, target: target)
        if possible < peak {
            let runs = kinds.filter { $0 != .off }.count
            let free = (1...C.daysPerWeek).first { kind($0) == .off }
            let next = free.map { day -> Double in
                var wider = structure
                wider[day] = .easy
                return possiblePeak(structure: wider, peakMeters: peak, paces: paces, target: target)
            }
            warnings.append(TrainerDayWarning(
                days: [], text: T.volumeWarning(runs: runs, possible: possible, peak: peak, nextPossible: runs < C.daysPerWeek ? next : nil)
            ))
        }
        let minimum = minimumWeek(structure: structure, meters: peak, paces: paces, target: target)
        if minimum > peak {
            let runs = kinds.filter { $0 != .off }.count
            warnings.append(TrainerDayWarning(days: [], text: T.minimumVolumeWarning(runs: runs, minimum: minimum, peak: peak)))
        }
        return warnings
    }

    public static func peakWeekMeters(
        structure: [Int: TrainerDayKind], peakMeters: Double, paces: TrainerPaces, target: TrainerTarget
    ) -> [Int: Double] {
        let week = previewWeek(meters: roundKilometers(peakMeters), paces: paces, target: target, structure: structure)
        let share = easyShare(
            week: week, weeks: [week], target: target, structure: structure, history: TrainerHistory(runs: []),
            today: week.start, paces: paces
        )
        var meters: [Int: Double] = [:]
        for day in 1...C.daysPerWeek {
            meters[day] = switch structure[day] ?? .off {
            case .easy: easyMeters(weekday: day, share: share)
            case .optionalEasy: share.optional
            case .long: week.longMeters
            case .threshold, .vo2max:
                qualityMeters(qualitySession(structure[day] ?? .off, week: week, weeks: [week], target: target, lowered: false))
            case .off, .race: 0
            }
        }
        return meters
    }

    public static func possiblePeak(
        structure: [Int: TrainerDayKind], peakMeters: Double, paces: TrainerPaces, target: TrainerTarget
    ) -> Double {
        var meters = roundKilometers(peakMeters)
        while meters > C.metersPerKilometer && capacity(structure: structure, meters: meters, paces: paces, target: target) < meters {
            meters -= C.metersPerKilometer
        }
        return meters
    }

    public static func alternatesQuality(_ structure: [Int: TrainerDayKind]) -> Bool {
        let kinds = (1...C.daysPerWeek).map { structure[$0] ?? .off }
        return kinds.filter { $0 != .off }.count <= C.singleQualityRuns && kinds.filter(C.qualityKinds.contains).count == 1
    }

    public static func qualityPerWeek(_ structure: [Int: TrainerDayKind]) -> Int {
        (1...C.daysPerWeek).filter { C.qualityKinds.contains(structure[$0] ?? .off) }.count
    }

    static func weekStructure(_ structure: [Int: TrainerDayKind], index: Int) -> [Int: TrainerDayKind] {
        guard index.isMultiple(of: 2), alternatesQuality(structure) else { return structure }
        return structure.mapValues { kind in
            switch kind {
            case .threshold: .vo2max
            case .vo2max: .threshold
            default: kind
            }
        }
    }

    static func easyLimit(paces: TrainerPaces) -> Double {
        floorKilometers(C.easyMaximumSeconds / paces.easy * C.metersPerKilometer)
    }

    static func easyMinimum(paces: TrainerPaces) -> Double {
        ceilKilometers(C.easyMinimumSeconds / paces.easy * C.metersPerKilometer)
    }

    static func optionalLimit(paces: TrainerPaces) -> Double {
        max(floorKilometers(C.optionalMaximumSeconds / paces.easy * C.metersPerKilometer), easyMinimum(paces: paces))
    }

    static func longLimit(weekMeters: Double, paces: TrainerPaces) -> Double {
        min(floorKilometers(C.longMaximumSeconds / paces.long * C.metersPerKilometer), floorKilometers(weekMeters * C.longWeekShare))
    }

    static func sizedLong(_ meters: Double, weekMeters: Double, paces: TrainerPaces) -> Double {
        max(min(meters, longLimit(weekMeters: weekMeters, paces: paces)), min(meters, C.minimumLongMeters))
    }

    static func cappedQuality(_ session: TrainerQualitySession, weekMeters: Double) -> TrainerQualitySession {
        let cap: Double
        switch (session.kind, session.method) {
        case (.threshold, .cruiseIntervals), (.threshold, .tempo): cap = weekMeters * C.thresholdWeekShare
        case (.vo2max, .intervals): cap = min(weekMeters * C.vo2WeekShare, C.vo2MaximumWorkMeters)
        default: return session
        }
        var blocks = session.blocks
        func work() -> Double { blocks.reduce(0.0) { $0 + Double($1.repeats) * $1.meters } }
        func repeats() -> Int { blocks.reduce(0) { $0 + $1.repeats } }
        while work() > cap, repeats() > C.minimumQualityRepeats, let last = blocks.indices.last {
            if blocks[last].repeats > 1 { blocks[last].repeats -= 1 } else { blocks.removeLast() }
        }
        if work() > cap {
            if repeats() == 1, let only = blocks.first {
                blocks = [TrainerQualityBlock(repeats: 1, meters: min(only.meters, max(floorKilometers(cap), C.minimumTempoMeters)))]
            } else {
                let size = max((cap / Double(C.minimumQualityRepeats) / C.halfKilometer).rounded(.down) * C.halfKilometer, C.minimumQualityBlockMeters)
                blocks = [TrainerQualityBlock(repeats: C.minimumQualityRepeats, meters: min(size, blocks.map(\.meters).max() ?? size))]
            }
        }
        return TrainerQualitySession(kind: session.kind, method: session.method, blocks: blocks, closing: session.closing, variant: session.variant)
    }

    static func longestLongs(
        _ weeks: [TrainerWeek], structure: [Int: TrainerDayKind], target: TrainerTarget, history: TrainerHistory, today: Day, paces: TrainerPaces
    ) -> [TrainerWeek] {
        weeks.map { week in
            let kinds = weekStructure(structure, week: week)
            guard kinds.values.contains(.long) else { return week }
            let longest = longestOtherRun(week: week, weeks: weeks, structure: kinds, target: target, history: history, today: today, paces: paces)
            guard longest > week.longMeters else { return week }
            var sized = week
            sized.longMeters = min(ceilKilometers(longest), floorKilometers(C.longMaximumSeconds / paces.long * C.metersPerKilometer))
            return sized
        }
    }

    static func longestOtherRun(
        week: TrainerWeek, weeks: [TrainerWeek], structure: [Int: TrainerDayKind], target: TrainerTarget, history: TrainerHistory,
        today: Day, paces: TrainerPaces
    ) -> Double {
        let share = easyShare(week: week, weeks: weeks, target: target, structure: structure, history: history, today: today, paces: paces)
        return structure.values.reduce(0.0) { longest, kind in
            let meters: Double = switch kind {
            case .easy: max(share.meters, share.first ?? 0, share.mediumLong ?? 0) + C.easyLongGapMeters
            case .optionalEasy: share.optional + C.easyLongGapMeters
            case .threshold, .vo2max: qualityMeters(qualitySession(kind, week: week, weeks: weeks, target: target, lowered: false))
            case .long, .off, .race: 0
            }
            return max(longest, meters)
        }
    }

    static func sizedWeeks(_ weeks: [TrainerWeek], paces: TrainerPaces) -> [TrainerWeek] {
        weeks.map { week in
            var sized = week
            sized.longMeters = sizedLong(week.longMeters, weekMeters: week.skeletonMeters, paces: paces)
            return sized
        }
    }

    static func floorKilometers(_ meters: Double) -> Double {
        (meters / C.metersPerKilometer).rounded(.down) * C.metersPerKilometer
    }

    static func ceilKilometers(_ meters: Double) -> Double {
        (meters / C.metersPerKilometer).rounded(.up) * C.metersPerKilometer
    }

    static func shifted(_ weekday: Int, by days: Int) -> Int {
        ((weekday - 1 + days) % C.daysPerWeek + C.daysPerWeek) % C.daysPerWeek + 1
    }

    private static func offset(_ weekday: Int, from long: Int) -> Int {
        (weekday - long + C.daysPerWeek) % C.daysPerWeek
    }

    private static func rank(_ weekday: Int, long: Int, in offsets: [Int]) -> Int {
        offsets.firstIndex { shifted(long, by: $0) == weekday } ?? offsets.count
    }

    private static func legStrengthDays(_ strength: [TrainerStrengthSession]) -> Set<Int> {
        Set(strength.filter { C.legGroups.contains($0.group) || $0.legLoad == .heavy }.map(\.weekday))
    }

    private static func suggestionCost(runs: [Int], quality: [Int], long: Int) -> Int {
        let strong = Set(quality + [long])
        let inARow = strong.filter { strong.contains(shifted($0, by: 1)) }.count
        let eve = quality.filter { shifted($0, by: 1) == long }.count
        let qualityRank = quality.reduce(0) { $0 + rank($1, long: long, in: C.qualityOffsets) }
        let easyRank = runs.filter { !quality.contains($0) }.reduce(0) { $0 + rank($1, long: long, in: C.easyOffsets) }
        return (inARow + eve) * C.ruleBreakCost + qualityRank * C.qualityRankWeight + easyRank
    }

    private static func combinations(_ items: [Int], _ size: Int) -> [[Int]] {
        guard size > 0 else { return [[]] }
        guard items.count >= size, let first = items.first else { return [] }
        let rest = Array(items.dropFirst())
        return combinations(rest, size - 1).map { [first] + $0 } + combinations(rest, size)
    }

    private static func previewWeek(
        meters: Double, paces: TrainerPaces, target: TrainerTarget, structure: [Int: TrainerDayKind] = [:]
    ) -> TrainerWeek {
        let week = TrainerWeek(
            index: 1, start: C.previewWeekStart, phase: .specific, isRecovery: false, plannedMeters: meters,
            longMeters: sizedLong(longCap(for: target, weekMeters: meters, paces: paces), weekMeters: meters, paces: paces),
            thresholdFocus: T.stageLabel(C.thresholdBlocks[C.thresholdBlocks.count - 1]), vo2Focus: ""
        )
        return longestLongs([week], structure: structure, target: target, history: TrainerHistory(runs: []), today: week.start, paces: paces)[0]
    }

    static func minimumWeek(structure: [Int: TrainerDayKind], meters: Double, paces: TrainerPaces, target: TrainerTarget) -> Double {
        let week = previewWeek(meters: meters, paces: paces, target: target, structure: structure)
        return (1...C.daysPerWeek).reduce(0.0) { total, day in
            let kind = structure[day] ?? .off
            let meters: Double = switch kind {
            case .easy, .optionalEasy: easyMinimum(paces: paces)
            case .long: week.longMeters
            case .threshold, .vo2max: qualityMeters(qualitySession(kind, week: week, weeks: [week], target: target, lowered: false))
            case .off, .race: 0
            }
            return total + meters
        }
    }

    static func capacity(
        structure: [Int: TrainerDayKind], meters: Double, paces: TrainerPaces, target: TrainerTarget, easySeconds: Double = C.easyMaximumSeconds
    ) -> Double {
        let week = previewWeek(meters: meters, paces: paces, target: target, structure: structure)
        return (1...C.daysPerWeek).reduce(0.0) { total, day in
            let kind = structure[day] ?? .off
            let meters: Double = switch kind {
            case .easy: floorKilometers(easySeconds / paces.easy * C.metersPerKilometer)
            case .optionalEasy: optionalLimit(paces: paces)
            case .long: week.longMeters
            case .threshold, .vo2max: qualityMeters(qualitySession(kind, week: week, weeks: [week], target: target, lowered: false))
            case .off, .race: 0
            }
            return total + meters
        }
    }
}
