import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    static func isProgressionWeek(_ week: TrainerWeek) -> Bool {
        !week.isRecovery && week.phase != .taper
    }

    static func progressionOrdinal(of week: TrainerWeek, in weeks: [TrainerWeek]) -> Int {
        weeks.filter { isProgressionWeek($0) && $0.index < week.index }.count
    }

    static func vo2Format(week: TrainerWeek, weeks: [TrainerWeek]) -> TrainerVo2Format {
        let sequence = weeks.filter { $0.phase != .taper && $0.index < week.index } + [week]
        var rotation = 0
        var format = C.vo2Rotation[0]
        for (ordinal, item) in sequence.enumerated() {
            if (item.phase == .base || item.phase == .general) && ordinal.isMultiple(of: 2) {
                format = .hills
            } else {
                format = C.vo2Rotation[rotation % C.vo2Rotation.count]
                rotation += 1
            }
        }
        return format
    }

    static func vo2Session(week: TrainerWeek, weeks: [TrainerWeek], lowered: Bool) -> TrainerQualitySession {
        func session(_ blocks: [TrainerQualityBlock], closing: Bool = true, variant: TrainerVariant? = nil) -> TrainerQualitySession {
            TrainerQualitySession(kind: .vo2max, method: .intervals, blocks: blocks, closing: closing, variant: variant)
        }
        if week.phase == .taper || lowered {
            let repeats = week.phase == .taper ? C.vo2TaperRepeats : C.vo2RecoveryRepeats
            return session([TrainerQualityBlock(repeats: repeats, meters: C.vo2OneKmMeters)])
        }
        let light = week.isRecovery
        switch vo2Format(week: week, weeks: weeks) {
        case .hills:
            let repeats = light ? C.hillRecoveryRepeats : C.hillRepeats
            return session([TrainerQualityBlock(repeats: repeats, meters: C.hillMeters)], closing: false, variant: .hills)
        case .oneKm:
            return session([TrainerQualityBlock(repeats: light ? C.vo2RecoveryRepeats : C.vo2OneKmRepeats, meters: C.vo2OneKmMeters)])
        case .eightHundred:
            let repeats = light ? C.eightHundredRecoveryRepeats : C.eightHundredRepeats
            return session([TrainerQualityBlock(repeats: repeats, meters: C.eightHundredMeters)])
        case .longReps:
            let full = week.phase == .base || week.phase == .general ? C.vo2LongBaseRepeats : C.vo2LongRepeats
            return session([TrainerQualityBlock(repeats: light ? C.longRecoveryRepeats : full, meters: C.vo2LongMeters)])
        case .shortReps:
            let repeats = light ? C.shortRecoveryRepeats : C.vo2ShortRepeats
            return session([TrainerQualityBlock(repeats: repeats, meters: C.vo2ShortMeters)])
        case .pyramid:
            let repeats = light ? 1 : C.vo2PyramidRepeats
            return session([
                TrainerQualityBlock(repeats: repeats, meters: C.vo2LongMeters),
                TrainerQualityBlock(repeats: repeats, meters: C.vo2OneKmMeters),
            ])
        }
    }

    static func labeledVo2(_ weeks: [TrainerWeek], from first: Int) -> [TrainerWeek] {
        weeks.map { week in
            guard week.index >= first else { return week }
            var labeled = week
            labeled.vo2Focus = T.sessionLabel(vo2Session(week: week, weeks: weeks, lowered: false).blocks)
            return labeled
        }
    }

    static func thresholdFormat(week: TrainerWeek, weeks: [TrainerWeek]) -> TrainerThresholdFormat {
        guard isProgressionWeek(week) else { return .ladder }
        let ordinal = progressionOrdinal(of: week, in: weeks)
        guard !ordinal.isMultiple(of: 2) else { return .ladder }
        if C.thresholdBlocks[stageIndex(of: week.thresholdFocus)] == 0 { return .progressive }
        return (ordinal / 2).isMultiple(of: 2) ? .continuous : .progressive
    }

    static func rotatedThreshold(week: TrainerWeek, weeks: [TrainerWeek]) -> TrainerQualitySession? {
        switch thresholdFormat(week: week, weeks: weeks) {
        case .ladder:
            return nil
        case .continuous:
            let meters = C.continuousTempoMeters[week.phase] ?? C.thresholdRecoveryMeters
            return TrainerQualitySession(
                kind: .threshold, method: .tempo, blocks: [TrainerQualityBlock(repeats: 1, meters: meters)], closing: false,
                variant: .continuousTempo
            )
        case .progressive:
            return TrainerQualitySession(
                kind: .threshold, method: .cruiseIntervals,
                blocks: [TrainerQualityBlock(repeats: C.progressiveThresholdRepeats, meters: C.progressiveThresholdMeters)],
                closing: false, variant: .progressiveThreshold
            )
        }
    }

    static func isFartlekWeek(_ week: TrainerWeek, weeks: [TrainerWeek]) -> Bool {
        !week.calm && isProgressionWeek(week) && progressionOrdinal(of: week, in: weeks) % C.fartlekEvery == 1
    }

    static func fartlekMinimumMeters() -> Double {
        ceilKilometers(C.warmupMeters + Double(2 * C.fartlekRepeats - 1) * C.fartlekMeters)
    }

    static func mediumLongDay(week: TrainerWeek, structure: [Int: TrainerDayKind]) -> Int? {
        guard week.targetMeters >= C.mediumLongWeekMeters, isProgressionWeek(week) else { return nil }
        let thresholds = (1...C.daysPerWeek).filter { structure[$0] == .threshold }
        let vo2s = (1...C.daysPerWeek).filter { structure[$0] == .vo2max }
        return (1...C.daysPerWeek).first { day in
            structure[day] == .easy && thresholds.contains { first in
                vo2s.contains { second in min(first, second) < day && day < max(first, second) }
            }
        }
    }

    static func easyMeters(weekday: Int, share: TrainerEasyShare) -> Double {
        if weekday == share.mediumLongDay, let meters = share.mediumLong { return meters }
        if weekday == share.firstDay, let meters = share.first { return meters }
        return share.meters
    }

    static func longRoles(_ weeks: [TrainerWeek], target: TrainerTarget) -> [Int: TrainerLongRole] {
        var roles: [Int: TrainerLongRole] = [:]
        var run = 0
        var last: TrainerLongStimulus?
        var lastAlternate: TrainerLongStimulus?
        for week in weeks.sorted(by: { $0.index < $1.index }) {
            guard isProgressionWeek(week) else {
                roles[week.index] = .plain
                run = 0
                continue
            }
            let position = run % C.blockLength
            run += 1
            guard position != 1 else {
                roles[week.index] = .longest
                continue
            }
            let stimulus: TrainerLongStimulus
            if last != .racePace, racePaceLongBlock(week: week, target: target) != nil,
               racePaceSession(week: week, weeks: weeks, target: target) == nil {
                stimulus = .racePace
            } else {
                stimulus = lastAlternate == .progressive ? .fastFinish : .progressive
                lastAlternate = stimulus
            }
            last = stimulus
            roles[week.index] = .stimulus(stimulus)
        }
        return roles
    }

    static func longRoom(week: TrainerWeek, weeks: [TrainerWeek], structure: [Int: TrainerDayKind], target: TrainerTarget, paces: TrainerPaces) -> Double {
        let kinds = weekStructure(structure, week: week).values
        let quality = kinds.filter(C.qualityKinds.contains).reduce(0.0) { total, kind in
            total + qualityMeters(qualitySession(kind, week: week, weeks: weeks, target: target, lowered: false))
        }
        let easyDays = Double(kinds.filter { $0 == .easy }.count)
        let optionalDays = Double(kinds.filter { $0 == .optionalEasy }.count)
        let optional = isFartlekWeek(week, weeks: weeks) ? max(fartlekMinimumMeters(), easyMinimum(paces: paces)) : easyMinimum(paces: paces)
        return week.targetMeters - quality - easyDays * easyMinimum(paces: paces) - optionalDays * optional
    }

    static func wavedLongs(
        _ weeks: [TrainerWeek], from first: Int, structure: [Int: TrainerDayKind], target: TrainerTarget, paces: TrainerPaces,
        mode: TrainerLongMode
    ) -> [TrainerWeek] {
        guard mode == .continuous else { return weeks }
        let roles = longRoles(weeks, target: target)
        let timeCap = floorKilometers(C.longMaximumSeconds / paces.long * C.metersPerKilometer)
        func room(_ week: TrainerWeek) -> Double {
            floorKilometers(longRoom(week: week, weeks: weeks, structure: structure, target: target, paces: paces))
        }
        func floored(_ week: TrainerWeek) -> Bool { week.targetMeters >= C.longFloorWeekMeters }
        func longest(_ week: TrainerWeek) -> (wave: Double, room: Double) {
            let wave = min(max(week.longMeters, min(
                roundKilometers(week.longMeters * C.longestGrowth), roundKilometers(longCap(for: target) * C.longestOverRaceCap),
                floorKilometers(week.targetMeters * C.longestWeekShare), timeCap
            )), C.longCeilingMeters)
            return (wave, min(max(week.longMeters, min(wave, room(week))), C.longCeilingMeters))
        }
        var blocks: [[TrainerWeek]] = []
        var run = 0
        for week in weeks.sorted(by: { $0.index < $1.index }) {
            guard isProgressionWeek(week) else {
                run = 0
                continue
            }
            if run % C.blockLength == 0 { blocks.append([]) }
            blocks[blocks.count - 1].append(week)
            run += 1
        }
        var waved: [Int: Double] = [:]
        for block in blocks {
            let peak = block.first { roles[$0.index] == .longest }.map { longest($0).room }
            for week in block {
                let base = week.longMeters
                if roles[week.index] == .longest {
                    waved[week.index] = peak ?? base
                    continue
                }
                var meters = min(base, roundKilometers(longest(week).wave * C.stimulusShare))
                var cap = peak.map { $0 - C.metersPerKilometer }
                if floored(week) {
                    meters = max(meters, min(C.longFloorMeters, base, room(week)))
                    if let peak, let below = cap { cap = max(below, min(C.longFloorMeters, peak)) }
                }
                if let cap { meters = min(meters, cap) }
                waved[week.index] = max(meters, min(base, C.minimumLongMeters))
            }
        }
        return weeks.map { week in
            guard week.index >= first, let meters = waved[week.index], meters != week.longMeters else { return week }
            var result = week
            result.baseLongMeters = week.longMeters
            result.longMeters = meters
            return result
        }
    }

    static func racePaceLongBlock(week: TrainerWeek, target: TrainerTarget) -> TrainerQualityBlock? {
        guard target.kind == .race, C.racePaceLongPhases.contains(week.phase), isProgressionWeek(week),
              (target.distanceMeters ?? 0) >= C.raceMinimumRaceMeters else { return nil }
        let size = week.longMeters < C.racePaceLongShortBelow ? C.racePaceLongShortMeters : C.racePaceLongMeters
        let block = TrainerQualityBlock(repeats: C.racePaceLongRepeats, meters: size)
        let used = Double(block.repeats) * size + Double(block.repeats - 1) * C.racePaceLongJogMeters
        return week.longMeters - used >= C.warmupMeters ? block : nil
    }

    static func stimulusLong(
        day: Day, week: TrainerWeek, stimulus: TrainerLongStimulus, paces: TrainerPaces, target: TrainerTarget,
        extras: [String], note: String?
    ) -> TrainerWorkout? {
        let meters = week.longMeters
        let easy = band(paces.long, C.easyBand)
        var steps: [TrainerStep] = []
        let text: String
        let title: String
        let variant: TrainerVariant
        switch stimulus {
        case .progressive:
            let final = paces.threshold + C.progressiveLongOffset
            guard final < paces.long else { return nil }
            let progressive = min(max(roundKilometers(meters * C.progressiveLongShare), C.progressiveLongMinimumMeters), C.progressiveLongMaximumMeters)
            let count = Int(progressive / C.metersPerKilometer)
            steps.append(TrainerStep(kind: .steady, meters: meters - progressive, paceLow: easy.low, paceHigh: easy.high))
            for index in 1...count {
                let range = band(paces.long + (final - paces.long) * Double(index) / Double(count), C.qualityBand)
                steps.append(TrainerStep(kind: .steady, meters: C.metersPerKilometer, paceLow: range.low, paceHigh: range.high))
            }
            text = T.progressiveLongReason(meters: progressive, from: paces.long, to: final)
            title = T.title(kind: .long, meters: meters, variant: .progressiveLong)
            variant = .progressiveLong
        case .fastFinish:
            let pace = paces.threshold + C.fastFinishOffset
            guard pace < paces.long else { return nil }
            let fast = band(pace, C.qualityBand)
            steps.append(TrainerStep(kind: .steady, meters: meters - C.fastFinishMeters, paceLow: easy.low, paceHigh: easy.high))
            steps.append(TrainerStep(kind: .steady, meters: C.fastFinishMeters, paceLow: fast.low, paceHigh: fast.high))
            text = T.fastFinishReason(meters: C.fastFinishMeters, pace: pace)
            title = T.title(kind: .long, meters: meters, variant: .fastFinish)
            variant = .fastFinish
        case .racePace:
            guard let block = racePaceLongBlock(week: week, target: target) else { return nil }
            let pace = paces.race ?? paces.threshold
            let work = band(pace, C.qualityBand)
            let used = Double(block.repeats) * block.meters + Double(block.repeats - 1) * C.racePaceLongJogMeters
            steps.append(TrainerStep(kind: .steady, meters: meters - used, paceLow: easy.low, paceHigh: easy.high))
            steps.append(TrainerStep(
                kind: .work, repeats: block.repeats, meters: block.meters, paceLow: work.low, paceHigh: work.high, method: .racePace
            ))
            steps.append(TrainerStep(
                kind: .recovery, repeats: block.repeats - 1, meters: C.racePaceLongJogMeters, paceLow: easy.low, paceHigh: easy.high
            ))
            let race = T.raceLabel(target.distanceMeters)
            text = T.racePaceLongReason(block: block, pace: pace, race: race, jog: C.racePaceLongJogMeters)
            title = T.racePaceLongTitle(meters: meters, block: block, race: race)
            variant = .racePaceLong
        }
        return TrainerWorkout(
            day: day, kind: .long, title: title, totalMeters: meters, steps: steps, paceLow: easy.low, paceHigh: easy.high,
            note: note, rationale: ([text] + T.noteSentence(note) + extras).joined(separator: " "), variant: variant
        )
    }

    static func stridesWorkout(day: Day, meters: Double, paces: TrainerPaces, rationale: String) -> TrainerWorkout {
        let easy = band(paces.easy, C.easyBand)
        let fast = band(paces.vo2max - C.repetitionBelowVo2, C.qualityBand)
        let strides = Double(C.stridesRepeats) * C.stridesMeters
        let steps = [
            TrainerStep(kind: .steady, meters: meters - strides, paceLow: easy.low, paceHigh: easy.high),
            TrainerStep(kind: .work, repeats: C.stridesRepeats, meters: C.stridesMeters, paceLow: fast.low, paceHigh: fast.high),
            TrainerStep(kind: .recovery, repeats: C.stridesRepeats - 1, meters: 0, restSeconds: C.stridesRestSeconds),
        ]
        return TrainerWorkout(
            day: day, kind: .easy, title: T.title(kind: .easy, meters: meters, variant: .strides), totalMeters: meters, steps: steps,
            paceLow: easy.low, paceHigh: easy.high, rationale: "\(rationale) \(T.stridesReason(rest: C.stridesRestSeconds))",
            variant: .strides
        )
    }

    static func mediumLongWorkout(day: Day, meters: Double, week: TrainerWeek, paces: TrainerPaces) -> TrainerWorkout {
        var workout = easyWorkout(day: day, meters: meters, paces: paces, rationale: T.mediumLongReason(meters: meters, week: week.targetMeters))
        workout.title = T.title(kind: .easy, meters: meters, variant: .mediumLong)
        workout.variant = .mediumLong
        return workout
    }

    static func fartlekWorkout(day: Day, meters: Double, paces: TrainerPaces) -> TrainerWorkout {
        let easy = band(paces.easy, C.easyBand)
        let strong = band((paces.threshold + paces.vo2max) / 2, C.qualityBand)
        let block = Double(2 * C.fartlekRepeats - 1) * C.fartlekMeters
        let steps = [
            TrainerStep(kind: .warmup, meters: meters - block, paceLow: easy.low, paceHigh: easy.high),
            TrainerStep(kind: .work, repeats: C.fartlekRepeats, meters: C.fartlekMeters, paceLow: strong.low, paceHigh: strong.high),
            TrainerStep(kind: .recovery, repeats: C.fartlekRepeats - 1, meters: C.fartlekMeters, paceLow: easy.low, paceHigh: easy.high),
        ]
        return TrainerWorkout(
            day: day, kind: .optionalEasy, title: T.title(kind: .optionalEasy, meters: meters, variant: .fartlek), totalMeters: meters,
            steps: steps, paceLow: easy.low, paceHigh: easy.high, note: T.fartlekNote(meters),
            rationale: T.fartlekReason(warmup: meters - block, meters: meters), variant: .fartlek
        )
    }
}
