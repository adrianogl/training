import Foundation
import Metrics
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    static func thresholdVolume(week: TrainerWeek, stage: Int) -> Double {
        if week.isRecovery || week.phase == .taper { return C.thresholdRecoveryMeters }
        switch week.phase {
        case .general, .base, .taper: return C.thresholdBaseMeters
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
        let cap = week.skeletonMeters * C.goalPaceBlockShare
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
        let session = plainQualitySession(kind, week: week, weeks: weeks, target: target, lowered: lowered, goalStep: goalStep)
        return week.outAndBack ? turned(session) : session
    }

    private static func plainQualitySession(
        _ kind: TrainerDayKind, week: TrainerWeek, weeks: [TrainerWeek], target: TrainerTarget, lowered: Bool, goalStep: Int?
    ) -> TrainerQualitySession {
        if kind == .vo2max, let ordinal = goalPaceOrdinal(week: week, weeks: weeks, target: target) {
            return goalPaceSession(step: goalStep ?? ordinal / C.goalPaceEvery, week: week, distance: target.distanceMeters ?? 0)
        }
        if kind == .vo2max {
            return cappedQuality(vo2Session(week: week, weeks: weeks, lowered: lowered), weekMeters: week.skeletonMeters)
        }
        if !lowered, let session = racePaceSession(week: week, weeks: weeks, target: target) { return session }
        if !lowered, let session = rotatedThreshold(week: week, weeks: weeks) { return cappedQuality(session, weekMeters: week.skeletonMeters) }
        return cappedQuality(thresholdSession(week: week, lowered: lowered), weekMeters: week.skeletonMeters)
    }

    static func qualityMeters(_ session: TrainerQualitySession) -> Double {
        let work = session.blocks.reduce(0.0) { $0 + Double($1.repeats) * $1.meters }
        let closing = session.closing ? Double(C.closingRepeats) * C.closingMeters + Double(C.closingRepeats - 1) * C.closingJogMeters : 0
        let jog = session.variant == .hills ? session.blocks.reduce(0.0) { $0 + Double($1.repeats - 1) * $1.meters } : 0
        return C.warmupMeters + work + closing + jog + session.tailMeters + session.warmupExtraMeters
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
        week: TrainerWeek, weeks: [TrainerWeek], target: TrainerTarget, structure: [Int: TrainerDayKind], history: TrainerHistory, today: Day,
        paces: TrainerPaces
    ) -> TrainerEasyShare {
        let base = easyBase(history: history, today: today)
        let kinds = (1...C.daysPerWeek).map { structure[$0] ?? .off }
        let quality = kinds.reduce(0.0) { total, kind in
            guard kind == .threshold || kind == .vo2max else { return total }
            return total + qualityMeters(qualitySession(kind, week: week, weeks: weeks, target: target, lowered: false))
        }
        let longMeters = kinds.contains(.long) ? week.longMeters : 0
        let easyDays = (1...C.daysPerWeek).filter { kinds[$0 - 1] == .easy }
        let optionalCount = Double(kinds.filter { $0 == .optionalEasy }.count)
        let fartlekWeek = optionalCount > 0 && isFartlekWeek(week, weeks: weeks)
        let unit = runUnit(week)
        let minimum = ceilRun(easyMinimum(paces: paces), unit: unit)
        let limit = floorRun(easyLimit(paces: paces), unit: unit)
        func allocate(mediumDay: Int?, mediumLong: Double) -> TrainerEasyShare {
            let regular = easyDays.filter { $0 != mediumDay }
            let count = Double(regular.count)
            let rest = week.targetMeters - longMeters - quality - (mediumDay == nil ? 0 : mediumLong)
            let fartlek = fartlekWeek && rest - count * minimum - optionalCount * fartlekMinimumMeters() >= 0
            let weight = count + optionalCount * C.optionalEasyShare
            let raw = weight > 0 ? rest / weight : 0
            var optional = min(max(roundRun(raw * C.optionalEasyShare, unit: unit), minimum), floorRun(optionalLimit(paces: paces), unit: unit))
            if fartlek { optional = max(optional, ceilRun(fartlekMinimumMeters(), unit: unit)) }
            let easyRaw = count > 0 ? (rest - optional * optionalCount) / count : 0
            let easy = min(max(roundRun(easyRaw, unit: unit), minimum), limit)
            let first = count > 0 ? min(max(roundRun(rest - optional * optionalCount - easy * (count - 1), unit: unit), minimum), limit) : nil
            return TrainerEasyShare(
                meters: easy, optional: optional, base: base.meters, fromHistory: base.fromHistory, first: first, firstDay: regular.first,
                mediumLong: mediumDay == nil ? nil : mediumLong, mediumLongDay: mediumDay, fartlek: fartlek
            )
        }
        if let day = mediumLongDay(week: week, structure: structure) {
            let target = roundKilometers(week.targetMeters * C.mediumLongShare)
            let optional = fartlekWeek ? max(ceilRun(fartlekMinimumMeters(), unit: unit), minimum) : minimum
            let room = week.targetMeters - longMeters - quality - Double(easyDays.count - 1) * minimum - optionalCount * optional
            let meters = floorRun(min(
                max(target, C.mediumLongMinimumMeters), C.mediumLongMaximumMeters, limit, floorKilometers(week.longMeters * C.mediumLongLongShare),
                floorKilometers(room)
            ), unit: unit)
            let share = allocate(mediumDay: day, mediumLong: meters)
            if meters >= min(C.mediumLongMinimumMeters, limit), meters > max(share.meters, share.first ?? 0) { return share }
        }
        return allocate(mediumDay: nil, mediumLong: 0)
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
        turnedSteps(plainQualitySteps(session: session, paces: paces, lowered: lowered), session: session, paces: paces)
    }

    private static func plainQualitySteps(session: TrainerQualitySession, paces: TrainerPaces, lowered: Bool) -> [TrainerStep] {
        let pace: Double = switch session.method {
        case .racePace, .goalPace: paces.race ?? paces.threshold
        case .intervals: paces.vo2max
        default: paces.threshold
        }
        let work = band(pace, C.qualityBand)
        let easy = band(paces.easy, C.easyBand)
        var steps = [TrainerStep(kind: .warmup, meters: C.warmupMeters, paceLow: easy.low, paceHigh: easy.high)]
        if session.variant == .hills, let block = session.blocks.first {
            steps.append(TrainerStep(kind: .work, repeats: block.repeats, meters: block.meters, method: session.method))
            steps.append(TrainerStep(kind: .recovery, repeats: block.repeats - 1, meters: block.meters))
            return steps
        }
        if session.variant == .progressiveThreshold, let block = session.blocks.first {
            let rest = restSeconds(session: session, block: block, paces: paces, lowered: lowered)
            for index in 0..<block.repeats {
                let offset = C.progressiveThresholdStep * Double(block.repeats - 1 - 2 * index) / 2
                let range = band(pace + offset, C.qualityBand)
                steps.append(TrainerStep(kind: .work, meters: block.meters, paceLow: range.low, paceHigh: range.high, method: session.method))
                if index < block.repeats - 1 { steps.append(TrainerStep(kind: .recovery, meters: 0, restSeconds: rest)) }
            }
            return steps
        }
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
        let work = steps.filter { $0.kind == .work && $0.method != .repetition }
        return TrainerWorkout(
            day: day, kind: session.kind, title: T.title(kind: session.kind, meters: qualityMeters(session), session: session),
            totalMeters: qualityMeters(session), steps: steps,
            paceLow: work.compactMap(\.paceLow).min(), paceHigh: work.compactMap(\.paceHigh).max(), note: note, rationale: rationale,
            method: session.method, variant: session.variant
        )
    }

    static func gelNote(history: TrainerHistory, meters: Double) -> String? {
        guard meters >= C.gelMinimumMeters else { return nil }
        guard let fade = history.runs.filter({ $0.kind == .long && $0.fadeKm != nil }).max(by: { $0.day < $1.day })?.fadeKm
        else { return nil }
        let km = max(1, fade - C.gelBeforeFadeKm)
        guard Double(km) * C.metersPerKilometer < meters else { return nil }
        return "gel no km \(km)"
    }

    static func detailWorkouts(
        weeks: [TrainerWeek], structure: [Int: TrainerDayKind], paces: TrainerPaces, history: TrainerHistory,
        target: TrainerTarget, today: Day, past: [TrainerWorkout], requests: [TrainerRequest], peakVolume: Double,
        long: TrainerLongPlan = TrainerLongPlan()
    ) -> [TrainerWorkout] {
        let reachedPeak = weeks.filter { !$0.isRecovery && $0.phase != .taper }.map(\.targetMeters).max() ?? 0
        let peakShortfall = target.date != nil && reachedPeak < peakVolume
        var loweredKinds: [TrainerDayKind: Day] = [:]
        for kind in [TrainerDayKind.threshold, .vo2max] {
            if let miss = missedQuality(kind, past: past, history: history, today: today) { loweredKinds[kind] = miss.day }
        }
        let roles = long.mode == .continuous ? longRoles(weeks, target: target) : [:]
        var workouts: [TrainerWorkout] = []
        let lastDay = (weeks.map(\.start).max() ?? today).adding(days: C.daysPerWeek - 1)
        let span = max(0, today.days(until: lastDay) + 1)
        for offset in 0..<span {
            let day = today.adding(days: offset)
            guard let week = weeks.first(where: { $0.start == day.weekStart }) else { continue }
            let weekday = week.start.days(until: day) + 1
            let plannedKinds = weekStructure(structure, index: week.index)
            let weekStructure = weekStructure(structure, week: week)
            var kind = weekStructure[weekday] ?? .off
            let isRaceWeek = target.date.map { $0.weekStart == week.start } ?? false
            if isRaceWeek, let raceDay = target.date {
                if day == raceDay { kind = .race } else if day > raceDay { kind = .off } else if kind != .off {
                    workouts.append(raceWeekWorkout(day: day, kind: kind, paces: paces, unit: runUnit(week)))
                    continue
                }
            }
            if let raceDay = target.date, day < raceDay, day.days(until: raceDay) < C.raceQualityGapDays, C.qualityKinds.contains(kind) {
                workouts.append(raceWeekWorkout(day: day, kind: kind, paces: paces, unit: runUnit(week)))
                continue
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
                let role = roles[week.index] ?? .plain
                var extras: [String] = []
                if peakShortfall && week.phase != .taper && !week.isRecovery {
                    extras.append(T.peakShortfall(requested: peakVolume, reached: reachedPeak))
                }
                if let suffix = longContinuousSuffix(long: long, week: week) { extras.append(suffix) }
                var stimulus: TrainerWorkout?
                if case .stimulus(let kind) = role {
                    stimulus = stimulusLong(day: day, week: week, stimulus: kind, paces: paces, target: target, extras: extras, note: note)
                }
                let head = role == .longest
                    ? T.longestReason(share: C.longestWeekShare, note: note)
                    : T.longRationale(week: week, previousLong: previousLong, cap: longCap(for: target, weekMeters: week.skeletonMeters, paces: paces), note: note)
                let rationale = ([head] + extras).joined(separator: " ")
                workout = (long.mode == .blocks ? longBlocksWorkout(day: day, week: week, paces: paces, long: long) : nil)
                    ?? progressiveLong(day: day, week: week, paces: paces, target: target, rationale: rationale, note: note)
                    ?? stimulus
                    ?? steadyWorkout(
                        day: day, kind: .long, meters: week.longMeters, pace: paces.long, band: C.easyBand,
                        title: T.title(kind: .long, meters: week.longMeters), note: note, rationale: rationale
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
                let previous = offset < C.detailDays ? past.last { $0.kind == kind && $0.day < day } : nil
                let previousStatus = previous.map { status(of: $0, history: history, today: today).status }
                let basis = kind == .threshold
                    ? T.thresholdBasis(paces, predicted: history.predictions[C.thresholdPredictionMeters])
                    : T.vo2Basis(paces, predicted: history.predictions[C.vo2PredictionMeters])
                let title = T.structureTitle(kind: kind, session: session)
                let goalNote = goalStep.map {
                    goalPaceNote(step: $0, day: day, week: week, weeks: weeks, target: target, paces: paces, past: past, history: history, today: today)
                }
                let miss = lowered && goalStep == nil ? missedQuality(kind, past: past, history: history, today: today) : nil
                let rationale = T.qualityRationale(
                    kind: kind, title: title, session: session, week: week, previousStatus: previousStatus,
                    miss: miss, basis: basis, restSeconds: restSeconds, goal: goalNote,
                    format: formatReason(kind: kind, session: session, week: week, weeks: weeks)
                )
                workout = qualityWorkout(
                    day: day, session: session, paces: paces, lowered: lowered, note: nil, rationale: rationale
                )
            case .optionalEasy:
                let share = easyShare(
                    week: week, weeks: weeks, target: target, structure: weekStructure, history: history, today: today, paces: paces
                )
                let meters = share.optional
                if share.fartlek, let score = history.readiness[day], score < C.optionalReadiness {
                    workout = easyWorkout(
                        day: day, kind: .optionalEasy, meters: meters, paces: paces, note: T.optionalNote,
                        rationale: T.fartlekSkipped(score, meters: meters)
                    )
                } else if share.fartlek {
                    workout = fartlekWorkout(day: day, meters: meters, paces: paces)
                } else {
                    workout = easyWorkout(
                        day: day, kind: .optionalEasy, meters: meters, paces: paces, note: T.optionalNote,
                        rationale: T.optionalRationale(meters: meters)
                    )
                }
            case .easy:
                let share = easyShare(
                    week: week, weeks: weeks, target: target, structure: weekStructure, history: history, today: today, paces: paces
                )
                let meters = easyMeters(weekday: weekday, share: share)
                if weekday == share.mediumLongDay {
                    workout = mediumLongWorkout(day: day, meters: meters, week: week, paces: paces)
                } else if week.lightKind == .training && C.qualityKinds.contains(plannedKinds[weekday] ?? .off)
                    || weekday == share.firstDay && !week.isRecovery && !week.calm {
                    workout = stridesWorkout(day: day, meters: meters, paces: paces, rationale: T.easyRationale(share, meters: meters))
                } else {
                    workout = easyWorkout(day: day, meters: meters, paces: paces, rationale: T.easyRationale(share, meters: meters))
                }
            }
            workouts.append(workout)
        }
        let result = applying(requests, to: workouts, paces: paces, today: today)
        let turning = Set(weeks.filter(\.outAndBack).map(\.start))
        return turning.isEmpty ? result : result.map { turning.contains($0.day.weekStart) ? withTurn($0) : $0 }
    }

    static func formatReason(kind: TrainerDayKind, session: TrainerQualitySession, week: TrainerWeek, weeks: [TrainerWeek]) -> String? {
        switch session.method {
        case .intervals where kind == .vo2max:
            return week.phase == .taper ? nil : T.vo2FormatReason(vo2Format(week: week, weeks: weeks))
        case .tempo, .cruiseIntervals:
            guard isProgressionWeek(week) else { return nil }
            let meters = session.blocks.reduce(0.0) { $0 + Double($1.repeats) * $1.meters }
            return T.thresholdFormatReason(thresholdFormat(week: week, weeks: weeks), meters: meters)
        default:
            return nil
        }
    }

    static func progressiveLong(
        day: Day, week: TrainerWeek, paces: TrainerPaces, target: TrainerTarget, rationale: String, note: String?
    ) -> TrainerWorkout? {
        guard target.kind == .paceDistance, let goal = target.goalPace, !week.isRecovery, week.phase != .taper
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

    static func raceWeekWorkout(day: Day, kind: TrainerDayKind, paces: TrainerPaces, unit: Double = C.metersPerKilometer) -> TrainerWorkout {
        if kind == .optionalEasy { return offWorkout(day: day, rationale: T.raceWeekEasy) }
        return easyWorkout(day: day, meters: floorRun(C.raceWeekEasyMeters, unit: unit), paces: paces, rationale: T.raceWeekEasy)
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
