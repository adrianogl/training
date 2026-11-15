import Foundation
import Metrics
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    static func qualityStage(_ kind: TrainerDayKind, week: TrainerWeek, lowered: Bool) -> TrainerQualityStage {
        let stages = kind == .threshold ? C.thresholdStages : C.vo2Stages
        let label = kind == .threshold ? week.thresholdFocus : week.vo2Focus
        let index = stageIndex(of: label, in: stages)
        return stages[lowered ? max(0, index - 1) : index]
    }

    static func qualityMeters(_ stage: TrainerQualityStage) -> Double {
        C.warmupMeters + Double(stage.repeats) * stage.meters
    }

    static func restSeconds(kind: TrainerDayKind, stage: TrainerQualityStage, paces: TrainerPaces, lowered: Bool) -> Double {
        let isThreshold = kind == .threshold
        let blockSeconds = stage.meters / C.metersPerKilometer * (isThreshold ? paces.threshold : paces.vo2max)
        let share = isThreshold ? C.thresholdRestShare : C.vo2RestShare
        let minimum = isThreshold ? C.thresholdMinimumRestSeconds : C.vo2MinimumRestSeconds
        let rounded = (max(blockSeconds * share, minimum) / C.restStepSeconds).rounded() * C.restStepSeconds
        return rounded + (lowered ? C.extraRestSeconds : 0)
    }

    static func easyBase(history: TrainerHistory, today: Day) -> (meters: Double, fromHistory: Bool) {
        let since = today.adding(days: -C.easyWindowDays)
        let distances = history.runs
            .filter { $0.kind == .easy && $0.meters > 0 && $0.day >= since && $0.day <= today }
            .map(\.meters)
        guard let middle = median(distances) else { return (C.fallbackEasyMeters, false) }
        return (min(max(roundHalfKilometers(middle), C.minimumEasyMeters), C.maximumEasyMeters), true)
    }

    static func easyShare(week: TrainerWeek, structure: [Int: TrainerDayKind], history: TrainerHistory, today: Day) -> TrainerEasyShare {
        let base = easyBase(history: history, today: today)
        let kinds = (1...C.daysPerWeek).map { structure[$0] ?? .off }
        let quality = kinds.reduce(0.0) { total, kind in
            guard kind == .threshold || kind == .vo2max else { return total }
            return total + qualityMeters(qualityStage(kind, week: week, lowered: false))
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

    static func qualityWorkout(
        day: Day, kind: TrainerDayKind, stage: TrainerQualityStage, restSeconds: Double, paces: TrainerPaces, note: String? = nil, rationale: String
    ) -> TrainerWorkout {
        let pace = kind == .threshold ? paces.threshold : paces.vo2max
        let work = band(pace, C.qualityBand)
        let easy = band(paces.easy, C.easyBand)
        let steps = [
            TrainerStep(kind: .warmup, meters: C.warmupMeters, paceLow: easy.low, paceHigh: easy.high),
            TrainerStep(kind: .work, repeats: stage.repeats, meters: stage.meters, paceLow: work.low, paceHigh: work.high),
            TrainerStep(kind: .recovery, repeats: stage.repeats - 1, meters: 0, restSeconds: restSeconds),
        ]
        return TrainerWorkout(
            day: day, kind: kind, title: T.title(kind: kind, meters: 0, stage: stage),
            totalMeters: qualityMeters(stage), steps: steps,
            paceLow: work.low, paceHigh: work.high, note: note, rationale: rationale
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
        strength: [TrainerStrengthSession]
    ) -> [TrainerWorkout] {
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
                workout = longWorkout(
                    day: day, week: week, paces: paces, note: note, slowStart: slowStart?.name,
                    rationale: T.longRationale(
                        week: week, previousLong: previousLong, cap: longCap(for: target), note: note, slowStart: slowStart?.name
                    )
                )
            case .threshold, .vo2max:
                let lowered = loweredKinds[kind].map { $0 < day } ?? false
                if lowered { loweredKinds[kind] = nil }
                let stage = qualityStage(kind, week: week, lowered: lowered)
                let restSeconds = restSeconds(kind: kind, stage: stage, paces: paces, lowered: lowered)
                let legs = sessions(before: day, in: strength).first(where: isLegHeavy)
                let previous = past.last { $0.kind == kind && $0.day < day }
                let previousStatus = previous.map { status(of: $0, history: history, today: today).status }
                let basis = kind == .threshold
                    ? T.thresholdBasis(paces, predicted: history.predictions[C.thresholdPredictionMeters])
                    : T.vo2Basis(paces, predicted: history.predictions[C.vo2PredictionMeters])
                let title = T.title(kind: kind, meters: 0, stage: stage)
                let miss = lowered ? missedQuality(kind, past: past, history: history, today: today) : nil
                let rationale = T.qualityRationale(
                    kind: kind, title: title, week: week, previous: previous, previousStatus: previousStatus,
                    miss: miss, basis: basis, restSeconds: restSeconds, legs: legs?.name
                )
                workout = qualityWorkout(
                    day: day, kind: kind, stage: stage, restSeconds: restSeconds,
                    paces: paces,
                    note: legs.map { T.legsNote($0.name) }, rationale: rationale
                )
            case .optionalEasy:
                let meters = easyShare(week: week, structure: structure, history: history, today: today).optional
                workout = easyWorkout(
                    day: day, kind: .optionalEasy, meters: meters, paces: paces, note: T.optionalNote,
                    rationale: T.optionalRationale(meters: meters)
                )
            case .easy:
                let share = easyShare(week: week, structure: structure, history: history, today: today)
                workout = easyWorkout(day: day, meters: share.meters, paces: paces, rationale: T.easyRationale(share))
            }
            workouts.append(workout)
        }
        return applying(requests, to: workouts, paces: paces, today: today)
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
