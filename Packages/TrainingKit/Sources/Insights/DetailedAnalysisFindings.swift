import FITReader
import Foundation
import Metrics
import TrainingCore
import WorkoutAnalysis

private typealias C = DetailedAnalysisConstants
private typealias K = DetailedEvidenceKey
private typealias T = DetailedAnalysisText

struct StartGroups: Equatable {
    var fastFaded = 0
    var fastTotal = 0
    var slowFaded = 0
    var slowTotal = 0
    var threshold = 0.0

    var fastRate: Double { fastTotal > 0 ? Double(fastFaded) / Double(fastTotal) : 0 }
    var slowRate: Double { slowTotal > 0 ? Double(slowFaded) / Double(slowTotal) : 0 }
}

func detailedFindings(_ context: DetailedContext) -> [DetailedFinding] {
    let ordered: [DetailedFinding?] = [
        completionFinding(context), fadeFinding(context), driftFinding(context), startPaceFinding(context), readinessFinding(context),
        weekLoadFinding(context), heartRateAtPaceFinding(context), pausesFinding(context), repetitionsFinding(context), goalFinding(context),
    ]
    return Array(ordered.compactMap { $0 }.prefix(C.maxFindings))
}

func startGroups(_ context: DetailedContext) -> StartGroups? {
    guard context.kind == .long, let start = context.current.startPace else { return nil }
    var groups = StartGroups(threshold: start + C.startMargin)
    for run in context.similar {
        guard let runStart = run.startPace else { continue }
        let faded = run.fadeKm.map { $0 < C.earlyFadeKm } ?? false
        if runStart < groups.threshold {
            groups.fastTotal += 1
            if faded { groups.fastFaded += 1 }
        } else {
            groups.slowTotal += 1
            if faded { groups.slowFaded += 1 }
        }
    }
    return groups.fastTotal > 0 && groups.slowTotal > 0 ? groups : nil
}

func readinessGroups(_ context: DetailedContext) -> (low: [Double], high: [Double], today: Int)? {
    guard let today = context.readiness[context.current.day.iso] else { return nil }
    var low: [Double] = []
    var high: [Double] = []
    for (run, percent) in zip(context.similar, context.similarPercents) {
        guard let percent, let score = context.readiness[run.day.iso] else { continue }
        if score < C.lowReadiness { low.append(percent) } else { high.append(percent) }
    }
    return low.isEmpty || high.isEmpty ? nil : (low, high, today)
}

func weekLoad(_ context: DetailedContext) -> (lastKm: Double, averageKm: Double, percent: Double, hadIntervals: Bool)? {
    let today = context.current.day
    let recentStart = today.adding(days: -C.recentDays)
    let baselineStart = recentStart.adding(days: -C.baselineWeeks * C.recentDays)
    var last = 0.0
    var baseline = 0.0
    var hadIntervals = false
    for record in context.runs {
        let day = PreparedRun.day(of: record)
        let kilometers = (record.distance ?? 0) / C.metersPerKilometer
        if day >= recentStart && day < today {
            last += kilometers
            if classifyRun(record, longGoalKm: context.longGoalKm, raceGoalKms: context.raceGoalKms) == .intervals { hadIntervals = true }
        } else if day >= baselineStart && day < recentStart {
            baseline += kilometers
        }
    }
    let averageKm = baseline / Double(C.baselineWeeks)
    guard last > 0, averageKm > 0 else { return nil }
    return (last, averageKm, (last / averageKm - 1) * 100, hadIntervals)
}

private func completionFinding(_ context: DetailedContext) -> DetailedFinding? {
    guard let planned = context.current.plannedMeters, let percent = context.currentPercent else { return nil }
    let done = context.current.meters
    let tone: DetailedTone = percent >= C.completeRatio ? .good : percent >= C.acceptableRatio ? .info : .fix
    let known = context.knownSimilarPercents
    var text = String(
        format: T.completionText, DetailedFormat.kilometers(done / C.metersPerKilometer), DetailedFormat.kilometers(planned / C.metersPerKilometer),
        DetailedFormat.whole(percent)
    )
    var evidence = [
        DetailedEvidence(key: K.percent, value: percent),
        DetailedEvidence(key: K.doneKm, value: done / C.metersPerKilometer),
        DetailedEvidence(key: K.plannedKm, value: planned / C.metersPerKilometer),
    ]
    if let mean = average(known) {
        text += String(format: T.completionAverage, known.count, DetailedFormat.whole(mean))
        evidence.append(DetailedEvidence(key: K.average, value: mean))
    }
    return DetailedFinding(
        kind: .completion, tone: tone,
        title: tone == .good ? T.completionTitleFull : String(format: T.completionTitleShort, DetailedFormat.whole(percent)),
        text: text, evidence: evidence
    )
}

private func fadeFinding(_ context: DetailedContext) -> DetailedFinding? {
    guard C.fadeKinds.contains(context.kind) else { return nil }
    let paces = context.current.splits.map(\.levelPace)
    guard let km = context.current.fadeKm, let baseline = median(Array(paces[0..<(km - 1)])) else { return nil }
    let slowdown = paces[km - 1] - baseline
    let leveled = context.current.splits.contains { $0.levelPace != $0.paceSeconds }
    var text = String(format: leveled ? T.fadeLevelText : T.fadeText, km, DetailedFormat.whole(slowdown), km - 1, DetailedFormat.pace(baseline))
    var evidence = [
        DetailedEvidence(key: K.fadeKm, value: Double(km)),
        DetailedEvidence(key: K.baselinePace, value: baseline),
        DetailedEvidence(key: K.slowdown, value: slowdown),
    ]
    if let similar = median(context.similar.compactMap { $0.fadeKm.map(Double.init) }) {
        text += String(format: T.fadeSimilar, DetailedFormat.whole(similar))
        evidence.append(DetailedEvidence(key: K.similarFadeKm, value: similar))
    }
    return DetailedFinding(kind: .fadeKm, tone: .fix, title: String(format: T.fadeTitle, km), text: text, evidence: evidence)
}

private func driftFinding(_ context: DetailedContext) -> DetailedFinding? {
    guard C.driftKinds.contains(context.kind), let drift = context.current.drift else { return nil }
    let mean = average(context.similar.compactMap(\.drift))
    var evidence = [DetailedEvidence(key: K.drift, value: drift)]
    if let mean { evidence.append(DetailedEvidence(key: K.driftAverage, value: mean)) }
    let suffix = mean.map { String(format: T.driftAverage, DetailedFormat.whole($0)) } ?? ""
    guard DetailedFormat.whole(drift) >= 1 else {
        return DetailedFinding(kind: .hrDrift, tone: .good, title: T.driftNoneTitle, text: T.driftNoneText + suffix, evidence: evidence)
    }
    return DetailedFinding(
        kind: .hrDrift, tone: drift >= C.driftFixPercent ? .fix : .info,
        title: String(format: T.driftTitle, DetailedFormat.whole(drift)),
        text: String(format: T.driftText, DetailedFormat.whole(drift)) + suffix + String(format: T.driftNormal, C.driftNormalPercent), evidence: evidence
    )
}

private func startPaceFinding(_ context: DetailedContext) -> DetailedFinding? {
    guard let start = context.current.startPace, let groups = startGroups(context) else { return nil }
    let fix = groups.fastRate > groups.slowRate
    let text = String(format: T.startText, C.startKm, DetailedFormat.pace(start))
        + String(
            format: T.startGroups, DetailedFormat.pace(groups.threshold), groups.fastFaded, groups.fastTotal, C.earlyFadeKm,
            groups.slowFaded, groups.slowTotal
        )
    return DetailedFinding(
        kind: .startPace, tone: fix ? .fix : .info, title: fix ? T.startFastTitle : String(format: T.startTitle, C.startKm), text: text,
        evidence: [
            DetailedEvidence(key: K.startPace, value: start),
            DetailedEvidence(key: K.fastFaded, value: Double(groups.fastFaded)),
            DetailedEvidence(key: K.fastTotal, value: Double(groups.fastTotal)),
            DetailedEvidence(key: K.slowFaded, value: Double(groups.slowFaded)),
            DetailedEvidence(key: K.slowTotal, value: Double(groups.slowTotal)),
        ]
    )
}

private func readinessFinding(_ context: DetailedContext) -> DetailedFinding? {
    guard let groups = readinessGroups(context), let low = average(groups.low), let high = average(groups.high) else { return nil }
    let fix = groups.today < C.lowReadiness && low < high
    let text = String(
        format: T.readinessText, groups.low.count, C.lowReadiness, DetailedFormat.whole(low), C.lowReadiness, DetailedFormat.whole(high)
    ) + String(format: T.readinessToday, groups.today)
    return DetailedFinding(
        kind: .readiness, tone: fix ? .fix : .info, title: fix ? T.readinessLowTitle : T.readinessTitle, text: text,
        evidence: [
            DetailedEvidence(key: K.lowMean, value: low),
            DetailedEvidence(key: K.highMean, value: high),
            DetailedEvidence(key: K.lowCount, value: Double(groups.low.count)),
            DetailedEvidence(key: K.highCount, value: Double(groups.high.count)),
            DetailedEvidence(key: K.readiness, value: Double(groups.today)),
        ]
    )
}

private func weekLoadFinding(_ context: DetailedContext) -> DetailedFinding? {
    guard let load = weekLoad(context) else { return nil }
    let heavy = load.percent >= C.heavyWeekPercent
    let text = String(
        format: T.weekText, C.recentDays, DetailedFormat.kilometers(load.lastKm), DetailedFormat.whole(abs(load.percent)),
        load.percent >= 0 ? T.weekAbove : T.weekBelow, C.baselineWeeks, DetailedFormat.kilometers(load.averageKm)
    ) + (load.hadIntervals ? T.weekIntervals : "")
    return DetailedFinding(
        kind: .weekLoad, tone: heavy ? .fix : .info, title: heavy ? T.weekTitleHeavy : T.weekTitle, text: text,
        evidence: [
            DetailedEvidence(key: K.weekKm, value: load.lastKm),
            DetailedEvidence(key: K.weekAverageKm, value: load.averageKm),
            DetailedEvidence(key: K.percent, value: load.percent),
            DetailedEvidence(key: K.hadIntervals, value: load.hadIntervals ? 1 : 0),
        ]
    )
}

private func heartRateAtPaceFinding(_ context: DetailedContext) -> DetailedFinding? {
    guard C.hrAtPaceKinds.contains(context.kind) else { return nil }
    let runs = context.similar.compactMap { run in
        run.averagePace.flatMap { pace in run.averageHeartRate.map { (day: run.day, pace: pace, heartRate: $0) } }
    }
    guard runs.count >= C.hrAtPaceMinimumRuns, let reference = median(runs.map(\.pace)),
          let origin = runs.first?.day, let end = runs.last?.day else { return nil }
    let span = origin.days(until: end)
    guard span > 0, let fit = linearFit(runs.map { (x: Double(origin.days(until: $0.day)), y: $0.heartRate) }) else { return nil }
    let first = fit.intercept
    let delta = fit.slope * Double(span)
    let last = first + delta
    let tone: DetailedTone = delta <= -C.heartRateStep ? .good : delta >= C.heartRateStep ? .fix : .info
    let title = tone == .good ? T.hrAtPaceImprovedTitle : tone == .fix ? T.hrAtPaceWorseTitle : T.hrAtPaceStableTitle
    return DetailedFinding(
        kind: .hrAtPace, tone: tone, title: title,
        text: String(format: T.hrAtPaceText, DetailedFormat.pace(reference), DetailedFormat.whole(first), DetailedFormat.whole(last), span),
        evidence: [
            DetailedEvidence(key: K.referencePace, value: reference),
            DetailedEvidence(key: K.firstBpm, value: first),
            DetailedEvidence(key: K.lastBpm, value: last),
            DetailedEvidence(key: K.deltaBpm, value: delta),
            DetailedEvidence(key: K.spanDays, value: Double(span)),
        ]
    )
}

private func pausesFinding(_ context: DetailedContext) -> DetailedFinding? {
    guard context.kind == .long, let continuity = context.current.continuity else { return nil }
    let longest = continuity.longestContinuousMeters / C.metersPerKilometer
    let evidence = [
        DetailedEvidence(key: K.pauses, value: Double(continuity.pauses.count)),
        DetailedEvidence(key: K.longestKm, value: longest),
    ]
    guard let first = continuity.pauses.first else {
        return DetailedFinding(
            kind: .pauses, tone: .good, title: T.pausesNoneTitle,
            text: String(format: T.pausesNoneText, DetailedFormat.kilometers(continuity.totalMeters / C.metersPerKilometer)), evidence: evidence
        )
    }
    let start = DetailedFormat.kilometers(first.startMeters / C.metersPerKilometer)
    let text = continuity.pauses.count == 1
        ? String(format: T.pausesOneText, start, DetailedFormat.kilometers(longest))
        : String(format: T.pausesText, continuity.pauses.count, start, DetailedFormat.kilometers(longest))
    return DetailedFinding(kind: .pauses, tone: .fix, title: T.pausesTitle, text: text, evidence: evidence)
}

private func repetitionsFinding(_ context: DetailedContext) -> DetailedFinding? {
    guard context.kind == .intervals,
          let laps = context.current.record.structureData.flatMap({ try? JSONDecoder().decode(WorkoutStructure.self, from: $0) })?.laps else { return nil }
    let paces = laps
        .filter { $0.intensity == .active && $0.distance > 0 && $0.timerSeconds > 0 }
        .map { $0.timerSeconds / ($0.distance / C.metersPerKilometer) }
    guard paces.count >= C.minimumReps, let spread = standardDeviation(paces) else { return nil }
    let samples = context.current.record.samplesData.flatMap { try? JSONDecoder().decode([FITSample].self, from: $0) } ?? []
    let drops = laps.filter { $0.intensity == .recovery }.compactMap { lap -> Double? in
        let rates = samples
            .filter { $0.t >= lap.startOffset && $0.t <= lap.startOffset + lap.timerSeconds }
            .sorted { $0.t < $1.t }
            .compactMap(\.heartRate)
        guard let first = rates.first, let last = rates.last else { return nil }
        return Double(first - last)
    }
    var text = String(format: T.repsText, paces.count, DetailedFormat.whole(spread))
    var evidence = [
        DetailedEvidence(key: K.repetitions, value: Double(paces.count)),
        DetailedEvidence(key: K.spread, value: spread),
    ]
    if let drop = average(drops) {
        text += String(format: T.repsRecovery, DetailedFormat.whole(drop))
        evidence.append(DetailedEvidence(key: K.recoveryDrop, value: drop))
    }
    return DetailedFinding(kind: .repsConsistency, tone: .info, title: T.repsTitle, text: text, evidence: evidence)
}

private func goalFinding(_ context: DetailedContext) -> DetailedFinding? {
    guard let goal = context.goals.first else { return nil }
    return DetailedFinding(
        kind: .goal, tone: goal.isMet ? .good : .info, title: String(format: T.goalTitle, goal.title),
        text: String(format: T.goalText, goal.status, goal.lines.joined(separator: " ")), evidence: []
    )
}
