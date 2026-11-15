import Foundation
import Metrics
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    static func thresholdVolume(week: TrainerWeek, stage: Int) -> Double {
        if week.isRecovery || week.phase == .taper { return C.thresholdRecoveryMeters }
        switch week.phase {
        case .base, .taper: return C.thresholdBaseMeters
        case .build: return C.thresholdBuildMeters[stage]
        case .specific: return C.thresholdSpecificMeters[stage]
        }
    }

    static func thresholdSession(week: TrainerWeek, lowered: Bool) -> TrainerQualitySession {
        if week.isRecovery {
            let blocks = C.thresholdPyramid.map { TrainerQualityBlock(repeats: 1, meters: $0) }
            return TrainerQualitySession(kind: .threshold, method: .cruiseIntervals, blocks: blocks, closing: false)
        }
        let stage = max(0, stageIndex(of: week.thresholdFocus) - (lowered ? 1 : 0))
        let volume = thresholdVolume(week: week, stage: stage)
        let size = C.thresholdBlocks[stage]
        if size == 0 {
            let blocks: [TrainerQualityBlock]
            if volume >= C.thresholdDoubleMinimumMeters {
                blocks = [TrainerQualityBlock(repeats: 2, meters: C.thresholdDoubleBlockMeters)]
            } else if volume >= C.thresholdSplitMinimumMeters {
                blocks = C.thresholdSplit.map { TrainerQualityBlock(repeats: 1, meters: $0) }
            } else {
                blocks = [TrainerQualityBlock(repeats: 1, meters: volume)]
            }
            return TrainerQualitySession(kind: .threshold, method: .tempo, blocks: blocks, closing: false)
        }
        var repeats = max(1, Int((volume / size).rounded()))
        if Double(repeats) * size > volume * 1.25 { repeats = max(1, repeats - 1) }
        return TrainerQualitySession(
            kind: .threshold, method: .cruiseIntervals, blocks: [TrainerQualityBlock(repeats: repeats, meters: size)], closing: false
        )
    }

    static func vo2Session(index: Int, isRecovery: Bool, phase: TrainerPhase, lowered: Bool) -> TrainerQualitySession {
        func session(_ blocks: [TrainerQualityBlock]) -> TrainerQualitySession {
            TrainerQualitySession(kind: .vo2max, method: .intervals, blocks: blocks, closing: true)
        }
        if isRecovery || phase == .taper || lowered {
            let repeats = phase == .taper ? C.vo2TaperRepeats : C.vo2RecoveryRepeats
            return session([TrainerQualityBlock(repeats: repeats, meters: C.vo2OneKmMeters)])
        }
        if index % C.vo2ShortEvery == 0 {
            return session([TrainerQualityBlock(repeats: C.vo2ShortRepeats, meters: C.vo2ShortMeters)])
        }
        switch index % C.vo2FormatCount {
        case 1:
            return session([TrainerQualityBlock(repeats: C.vo2OneKmRepeats, meters: C.vo2OneKmMeters)])
        case 2:
            let repeats = phase == .base ? C.vo2LongBaseRepeats : C.vo2LongRepeats
            return session([TrainerQualityBlock(repeats: repeats, meters: C.vo2LongMeters)])
        default:
            return session([
                TrainerQualityBlock(repeats: C.vo2PyramidRepeats, meters: C.vo2LongMeters),
                TrainerQualityBlock(repeats: C.vo2PyramidRepeats, meters: C.vo2OneKmMeters),
            ])
        }
    }

    static func racePaceSession(week: TrainerWeek, weeks: [TrainerWeek], target: TrainerTarget) -> TrainerQualitySession? {
        guard target.kind == .race, week.phase == .specific, !week.isRecovery, let distance = target.distanceMeters,
              distance >= C.raceMinimumRaceMeters else { return nil }
        let ordinal = weeks.filter { $0.phase == .specific && !$0.isRecovery && $0.index <= week.index }.count - 1
        guard ordinal >= 0, ordinal % C.raceEvery == 0 else { return nil }
        let cap = min(roundKilometers(distance * C.raceShare), C.raceMaximumMeters)
        let total = min(cap, C.raceStartMeters + C.raceStepMeters * Double(ordinal / C.raceEvery))
        let block = total >= cap
            ? TrainerQualityBlock(repeats: 1, meters: cap)
            : TrainerQualityBlock(repeats: Int(total / C.raceBlockMeters), meters: C.raceBlockMeters)
        return TrainerQualitySession(kind: .threshold, method: .racePace, blocks: [block], closing: false)
    }

    static func goalPaceWeeks(_ weeks: [TrainerWeek], upTo index: Int? = nil) -> [TrainerWeek] {
        weeks.filter { week in !week.isRecovery && week.phase != .taper && week.index <= (index ?? .max) }
    }

    static func goalPaceOrdinal(week: TrainerWeek, weeks: [TrainerWeek], target: TrainerTarget) -> Int? {
        guard target.kind == .paceDistance, target.goalPace != nil, (target.distanceMeters ?? 0) > 0,
              !week.isRecovery, week.phase != .taper else { return nil }
        let ordinal = goalPaceWeeks(weeks, upTo: week.index).count - 1
        return ordinal >= 0 && ordinal % C.goalPaceEvery == 0 ? ordinal : nil
    }

    static func goalPaceBlock(step: Int, distance: Double) -> TrainerQualityBlock {
        var block: TrainerQualityBlock
        if step < C.goalPaceLadder.count {
            let rung = C.goalPaceLadder[step]
            block = TrainerQualityBlock(repeats: rung.repeats, meters: rung.meters)
        } else {
            let extra = Double(step - C.goalPaceLadder.count + 1) * C.goalPaceExtraMeters
            block = TrainerQualityBlock(repeats: 1, meters: (C.goalPaceLadder.last?.meters ?? 0) + extra)
        }
        if Double(block.repeats) * block.meters > distance { block = TrainerQualityBlock(repeats: 1, meters: distance) }
        return block
    }

    static func goalPaceSession(step: Int, week: TrainerWeek, distance: Double) -> TrainerQualitySession {
        var block = goalPaceBlock(step: step, distance: distance)
        let cap = week.targetMeters * C.goalPaceBlockShare
        if block.repeats > 1 && Double(block.repeats) * block.meters > cap {
            block.repeats = max(1, Int(cap / block.meters))
        }
        return TrainerQualitySession(kind: .vo2max, method: .goalPace, blocks: [block], closing: false)
    }

    static func goalPaceTotal(step: Int, distance: Double) -> Double {
        let block = goalPaceBlock(step: step, distance: distance)
        return Double(block.repeats) * block.meters
    }

    static func goalPaceStepsToTarget(distance: Double) -> Int {
        (0..<C.goalPaceStepLimit).first { goalPaceTotal(step: $0, distance: distance) >= distance } ?? C.goalPaceStepLimit
    }

    static func goalPaceShortfall(step: Int, week: TrainerWeek, weeks: [TrainerWeek], target: TrainerTarget) -> String? {
        guard target.date != nil, let distance = target.distanceMeters else { return nil }
        let remaining = goalPaceWeeks(weeks).enumerated()
            .filter { $0.offset % C.goalPaceEvery == 0 && $0.element.index >= week.index }.count
        let last = step + max(remaining, 1) - 1
        guard last < goalPaceStepsToTarget(distance: distance) else { return nil }
        return T.goalPaceShortfall(reached: goalPaceTotal(step: last, distance: distance), target: distance)
    }

    static func goalPaceStep(day: Day, today: Day, past: [TrainerWorkout], generated: [TrainerWorkout], history: TrainerHistory) -> Int {
        let closed = past.filter {
            $0.method == .goalPace && $0.day < day && status(of: $0, history: history, today: today).status == .done
        }.count
        let planned = generated.filter { item in
            item.method == .goalPace && item.day < day && !past.contains { $0.day == item.day }
        }.count
        return closed + planned
    }

    static func goalPaceNote(
        step: Int, day: Day, week: TrainerWeek, weeks: [TrainerWeek], target: TrainerTarget, paces: TrainerPaces,
        past: [TrainerWorkout], history: TrainerHistory, today: Day
    ) -> TrainerGoalPaceNote {
        var closed: Bool?
        if let last = past.last(where: { $0.method == .goalPace && $0.day < day }) {
            let state = status(of: last, history: history, today: today).status
            if state != .planned && state != .today { closed = state == .done }
        }
        return TrainerGoalPaceNote(
            pace: target.goalPace ?? paces.threshold, previousClosed: closed,
            shortfall: goalPaceShortfall(step: step, week: week, weeks: weeks, target: target)
        )
    }

    static func qualitySession(
        _ kind: TrainerDayKind, week: TrainerWeek, weeks: [TrainerWeek], target: TrainerTarget, lowered: Bool, goalStep: Int? = nil
    ) -> TrainerQualitySession {
        if kind == .vo2max, let ordinal = goalPaceOrdinal(week: week, weeks: weeks, target: target) {
            return goalPaceSession(step: goalStep ?? ordinal / C.goalPaceEvery, week: week, distance: target.distanceMeters ?? 0)
        }
        if kind == .vo2max {
            return vo2Session(index: week.index, isRecovery: week.isRecovery, phase: week.phase, lowered: lowered)
        }
        if !lowered, let session = racePaceSession(week: week, weeks: weeks, target: target) { return session }
        return thresholdSession(week: week, lowered: lowered)
    }

    static func qualityMeters(_ session: TrainerQualitySession) -> Double {
        let work = session.blocks.reduce(0.0) { $0 + Double($1.repeats) * $1.meters }
        let closing = session.closing ? Double(C.closingRepeats) * C.closingMeters + Double(C.closingRepeats - 1) * C.closingJogMeters : 0
        return C.warmupMeters + work + closing
    }

    static func restSeconds(session: TrainerQualitySession, block: TrainerQualityBlock, paces: TrainerPaces, lowered: Bool) -> Double {
        let extra = lowered ? C.extraRestSeconds : 0
        switch session.method {
        case .racePace:
            let blocks = session.blocks.first?.repeats ?? 1
            return min(C.raceRestSeconds + C.raceRestStepSeconds * Double(max(0, blocks - 2)), C.raceRestMaximumSeconds)
        case .goalPace:
            return block.meters <= C.goalPaceShortBlockMeters ? C.goalPaceShortRestSeconds : C.goalPaceLongRestSeconds
        case .intervals:
            let seconds = block.meters / C.metersPerKilometer * paces.vo2max * C.vo2RestShare
            let rounded = (seconds / C.restStepSeconds).rounded() * C.restStepSeconds
            let minimum = block.meters < C.vo2ShortRepMeters ? C.vo2ShortRestMinimumSeconds : C.vo2MinimumRestSeconds
            return max(rounded, minimum) + extra
        default:
            let seconds = block.meters / C.metersPerKilometer * C.thresholdRestSecondsPerKm
            return min(max(seconds, C.thresholdMinimumRestSeconds) + extra, C.thresholdMaximumRestSeconds)
        }
    }

    static func easyBase(history: TrainerHistory, today: Day) -> (meters: Double, fromHistory: Bool) {
        let since = today.adding(days: -C.easyWindowDays)
        let distances = history.runs
            .filter { $0.kind == .easy && $0.meters > 0 && $0.day >= since && $0.day <= today }
            .map(\.meters)
        guard let middle = median(distances) else { return (C.fallbackEasyMeters, false) }
        return (min(max(roundHalfKilometers(middle), C.minimumEasyMeters), C.maximumEasyMeters), true)
    }

    static func easyShare(
        week: TrainerWeek, weeks: [TrainerWeek], target: TrainerTarget, structure: [Int: TrainerDayKind], history: TrainerHistory, today: Day
    ) -> TrainerEasyShare {
        let base = easyBase(history: history, today: today)
        let kinds = (1...C.daysPerWeek).map { structure[$0] ?? .off }
        let quality = kinds.reduce(0.0) { total, kind in
            guard kind == .threshold || kind == .vo2max else { return total }
            return total + qualityMeters(qualitySession(kind, week: week, weeks: weeks, target: target, lowered: false))
        }
        let longMeters = kinds.contains(.long) ? week.longMeters : 0
        let easyCount = Double(kinds.filter { $0 == .easy }.count)
        let optionalCount = Double(kinds.filter { $0 == .optionalEasy }.count)
        let weight = easyCount + optionalCount * C.optionalEasyShare
        let raw = weight > 0 ? (week.targetMeters - longMeters - quality) / weight : 0
        let easy = min(max(roundHalfKilometers(raw), C.minimumEasyMeters), C.maximumEasyMeters)
        let optional = min(max(roundHalfKilometers(raw * C.optionalEasyShare), C.optionalMinimumMeters), C.maximumEasyMeters)
        return TrainerEasyShare(meters: easy, optional: optional, base: base.meters, fromHistory: base.fromHistory)
    }

    static func missedQuality(
        _ kind: TrainerDayKind, past: [TrainerWorkout], history: TrainerHistory, today: Day
    ) -> TrainerQualityMiss? {
        guard let last = past.last(where: { $0.kind == kind && $0.day <= today }) else { return nil }
        let result = status(of: last, history: history, today: today)
        guard result.status == .offTarget, let run = result.run,
              let on = run.activeOnTarget, let total = run.activeTotal else { return nil }
        return TrainerQualityMiss(kind: kind, day: last.day, onTarget: on, total: total)
    }

    static func steadyWorkout(
        day: Day, kind: TrainerDayKind, meters: Double, pace: Double, band width: Double, title: String,
        note: String? = nil, rationale: String
    ) -> TrainerWorkout {
        let range = band(pace, width)
        let step = TrainerStep(kind: .steady, meters: meters, paceLow: range.low, paceHigh: range.high)
        return TrainerWorkout(
            day: day, kind: kind, title: title, totalMeters: meters, steps: [step],
            paceLow: range.low, paceHigh: range.high, note: note, rationale: rationale
        )
    }

    static func offWorkout(day: Day, rationale: String = "Dia de descanso da estrutura semanal.") -> TrainerWorkout {
        TrainerWorkout(day: day, kind: .off, title: T.offTitle, totalMeters: 0, steps: [], rationale: rationale)
    }

    static func easyWorkout(
        day: Day, kind: TrainerDayKind = .easy, meters: Double, paces: TrainerPaces, note: String? = nil, rationale: String
    ) -> TrainerWorkout {
        steadyWorkout(
            day: day, kind: kind, meters: meters, pace: paces.easy, band: C.easyBand,
            title: T.title(kind: kind, meters: meters), note: note, rationale: rationale
        )
    }

    static func qualitySteps(session: TrainerQualitySession, paces: TrainerPaces, lowered: Bool) -> [TrainerStep] {
        let pace: Double = switch session.method {
        case .racePace, .goalPace: paces.race ?? paces.threshold
        case .intervals: paces.vo2max
        default: paces.threshold
        }
        let work = band(pace, C.qualityBand)
        let easy = band(paces.easy, C.easyBand)
        var steps = [TrainerStep(kind: .warmup, meters: C.warmupMeters, paceLow: easy.low, paceHigh: easy.high)]
        for (index, block) in session.blocks.enumerated() {
            let rest = restSeconds(session: session, block: block, paces: paces, lowered: lowered)
            steps.append(TrainerStep(
                kind: .work, repeats: block.repeats, meters: block.meters, paceLow: work.low, paceHigh: work.high, method: session.method
            ))
            if block.repeats > 1 { steps.append(TrainerStep(kind: .recovery, repeats: block.repeats - 1, meters: 0, restSeconds: rest)) }
            if index < session.blocks.count - 1 || session.closing {
                steps.append(TrainerStep(kind: .recovery, meters: 0, restSeconds: rest))
            }
        }
        if session.closing {
            let repetition = band(paces.vo2max - C.repetitionBelowVo2, C.qualityBand)
            steps.append(TrainerStep(
                kind: .work, repeats: C.closingRepeats, meters: C.closingMeters, paceLow: repetition.low, paceHigh: repetition.high,
                method: .repetition
            ))
            steps.append(TrainerStep(kind: .recovery, repeats: C.closingRepeats - 1, meters: C.closingJogMeters))
        }
        return steps
    }

    static func qualityWorkout(
        day: Day, session: TrainerQualitySession, paces: TrainerPaces, lowered: Bool, note: String? = nil, rationale: String
    ) -> TrainerWorkout {
        let steps = qualitySteps(session: session, paces: paces, lowered: lowered)
        let work = steps.first { $0.kind == .work }
        return TrainerWorkout(
            day: day, kind: session.kind, title: T.title(kind: session.kind, meters: 0, session: session),
            totalMeters: qualityMeters(session), steps: steps,
            paceLow: work?.paceLow, paceHigh: work?.paceHigh, note: note, rationale: rationale, method: session.method
        )
    }

    static func gelNote(history: TrainerHistory, meters: Double) -> String? {
        guard let fade = history.runs.filter({ $0.kind == .long && $0.fadeKm != nil }).max(by: { $0.day < $1.day })?.fadeKm
        else { return nil }
        let km = max(1, fade - C.gelBeforeFadeKm)
        guard Double(km) * C.metersPerKilometer < meters else { return nil }
        return "gel no km \(km)"
    }

    static func detailWorkouts(
        weeks: [TrainerWeek], structure: [Int: TrainerDayKind], paces: TrainerPaces, history: TrainerHistory,
        target: TrainerTarget, today: Day, past: [TrainerWorkout], requests: [TrainerRequest],
        strength: [TrainerStrengthSession], peakVolume: Double
    ) -> [TrainerWorkout] {
        let reachedPeak = weeks.filter { !$0.isRecovery && $0.phase != .taper }.map(\.targetMeters).max() ?? 0
        let peakShortfall = target.date != nil && reachedPeak < peakVolume
        var loweredKinds: [TrainerDayKind: Day] = [:]
        for kind in [TrainerDayKind.threshold, .vo2max] {
            if let miss = missedQuality(kind, past: past, history: history, today: today) { loweredKinds[kind] = miss.day }
        }
        var workouts: [TrainerWorkout] = []
        for offset in 0..<C.detailDays {
            let day = today.adding(days: offset)
            guard let week = weeks.first(where: { $0.start == day.weekStart }) else { continue }
            let weekday = week.start.days(until: day) + 1
            var kind = structure[weekday] ?? .off
            let isRaceWeek = target.date.map { $0.weekStart == week.start } ?? false
            if isRaceWeek, let raceDay = target.date {
                if day == raceDay { kind = .race } else if day > raceDay { kind = .off } else if kind != .off {
                    workouts.append(raceWeekWorkout(day: day, kind: kind, paces: paces))
                    continue
                }
            }
            let workout: TrainerWorkout
            switch kind {
            case .off:
                workout = offWorkout(day: day)
            case .race:
                workout = raceWorkout(day: day, target: target, paces: paces)
            case .long:
                let note = gelNote(history: history, meters: week.longMeters)
                let previousLong = weeks.first(where: { $0.index == week.index - 1 })?.longMeters
                let slowStart = sessions(before: day, in: strength).first { $0.group == .lower || $0.group == .fullBody }
                var rationale = T.longRationale(
                    week: week, previousLong: previousLong, cap: longCap(for: target), note: note, slowStart: slowStart?.name
                )
                if peakShortfall && week.phase != .taper && !week.isRecovery {
                    rationale += " \(T.peakShortfall(requested: peakVolume, reached: reachedPeak))"
                }
                workout = progressiveLong(
                    day: day, week: week, paces: paces, target: target, rationale: rationale, slowStart: slowStart?.name, note: note
                ) ?? longWorkout(
                    day: day, week: week, paces: paces, note: note, slowStart: slowStart?.name, rationale: rationale
                )
            case .threshold, .vo2max:
                let lowered = loweredKinds[kind].map { $0 < day } ?? false
                if lowered { loweredKinds[kind] = nil }
                let goalStep = kind != .vo2max || goalPaceOrdinal(week: week, weeks: weeks, target: target) == nil
                    ? nil : goalPaceStep(day: day, today: today, past: past, generated: workouts, history: history)
                let session = qualitySession(kind, week: week, weeks: weeks, target: target, lowered: lowered && goalStep == nil, goalStep: goalStep)
                let restSeconds = restSeconds(
                    session: session, block: session.blocks[0], paces: paces, lowered: lowered
                )
                let legs = sessions(before: day, in: strength).first(where: isLegHeavy)
                let previous = past.last { $0.kind == kind && $0.day < day }
                let previousStatus = previous.map { status(of: $0, history: history, today: today).status }
                let basis = kind == .threshold
                    ? T.thresholdBasis(paces, predicted: history.predictions[C.thresholdPredictionMeters])
                    : T.vo2Basis(paces, predicted: history.predictions[C.vo2PredictionMeters])
                let title = T.title(kind: kind, meters: 0, session: session)
                let goalNote = goalStep.map {
                    goalPaceNote(step: $0, day: day, week: week, weeks: weeks, target: target, paces: paces, past: past, history: history, today: today)
                }
                let miss = lowered && goalStep == nil ? missedQuality(kind, past: past, history: history, today: today) : nil
                let rationale = T.qualityRationale(
                    kind: kind, title: title, session: session, week: week, previousStatus: previousStatus,
                    miss: miss, basis: basis, restSeconds: restSeconds, legs: legs?.name, goal: goalNote
                )
                workout = qualityWorkout(
                    day: day, session: session, paces: paces, lowered: lowered,
                    note: legs.map { T.legsNote($0.name) }, rationale: rationale
                )
            case .optionalEasy:
                let meters = easyShare(week: week, weeks: weeks, target: target, structure: structure, history: history, today: today).optional
                workout = easyWorkout(
                    day: day, kind: .optionalEasy, meters: meters, paces: paces, note: T.optionalNote,
                    rationale: T.optionalRationale(meters: meters)
                )
            case .easy:
                let share = easyShare(week: week, weeks: weeks, target: target, structure: structure, history: history, today: today)
                workout = easyWorkout(day: day, meters: share.meters, paces: paces, rationale: T.easyRationale(share))
            }
            workouts.append(workout)
        }
        return applying(requests, to: workouts, paces: paces, today: today)
    }

    static func progressiveLong(
        day: Day, week: TrainerWeek, paces: TrainerPaces, target: TrainerTarget, rationale: String, slowStart: String?, note: String?
    ) -> TrainerWorkout? {
        guard target.kind == .paceDistance, let goal = target.goalPace, slowStart == nil, !week.isRecovery, week.phase != .taper
        else { return nil }
        let final = goal + C.goalPaceLongOffset
        guard final < paces.long else { return nil }
        let growth = Double((week.index - 1) / C.goalPaceLongWeeksPerKm) * C.metersPerKilometer
        let progressive = min(
            min(C.goalPaceLongMinimumMeters + growth, C.goalPaceLongMaximumMeters), (week.longMeters / 2 / C.metersPerKilometer).rounded(.down) * C.metersPerKilometer
        )
        guard progressive >= C.metersPerKilometer else { return nil }
        let count = Int(progressive / C.metersPerKilometer)
        let easy = band(paces.long, C.easyBand)
        var steps = [TrainerStep(kind: .steady, meters: week.longMeters - progressive, paceLow: easy.low, paceHigh: easy.high)]
        for index in 1...count {
            let pace = paces.long + (final - paces.long) * Double(index) / Double(count)
            let range = band(pace, C.qualityBand)
            steps.append(TrainerStep(kind: .steady, meters: C.metersPerKilometer, paceLow: range.low, paceHigh: range.high))
        }
        return TrainerWorkout(
            day: day, kind: .long, title: T.title(kind: .long, meters: week.longMeters), totalMeters: week.longMeters, steps: steps,
            paceLow: easy.low, paceHigh: easy.high, note: note,
            rationale: "\(rationale) \(T.goalPaceLong(meters: progressive, from: paces.long, to: final))"
        )
    }

    static func raceWeekWorkout(day: Day, kind: TrainerDayKind, paces: TrainerPaces) -> TrainerWorkout {
        if kind == .optionalEasy { return offWorkout(day: day, rationale: T.raceWeekEasy) }
        return easyWorkout(day: day, meters: C.raceWeekEasyMeters, paces: paces, rationale: T.raceWeekEasy)
    }

    static func raceWorkout(day: Day, target: TrainerTarget, paces: TrainerPaces) -> TrainerWorkout {
        let meters = target.distanceMeters ?? 0
        let pace = paces.race ?? paces.threshold
        return steadyWorkout(
            day: day, kind: .race, meters: meters, pace: pace, band: C.qualityBand,
            title: meters > 0 ? T.title(kind: .race, meters: meters) : "Prova",
            rationale: T.raceRationale(target: target, pace: paces.race)
        )
    }
}
