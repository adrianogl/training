import TrainingCore
import FITReader

public func scoreWorkout(blocks: [WorkoutBlock], zones: HeartRateZones?, previous: [WorkoutOccurrence]) -> WorkoutScore? {
    guard !blocks.isEmpty else { return nil }
    let prescribed = blocks.contains { $0.prescribed != nil }
    let hasHeartRate = blocks.contains { $0.avgHeartRate != nil }
    let items = [
        executionItem(blocks, prescribed: prescribed),
        intentItem(blocks, zones: zones, prescribed: prescribed, hasHeartRate: hasHeartRate),
        costItem(blocks, previous: previous, hasHeartRate: hasHeartRate),
    ]
    let maximum = items.reduce(0) { $0 + $1.maximum }
    guard maximum > 0 else { return nil }
    let points = items.reduce(0) { $0 + $1.points }
    return WorkoutScore(value: Int((points / maximum * AnalysisConstants.scoreScale).rounded()), items: items)
}

private func absent(_ part: ScorePart, _ reason: ScoreReason) -> ScoreItem {
    ScoreItem(part: part, points: 0, maximum: 0, reason: reason)
}

private func isExecuted(_ block: WorkoutBlock) -> Bool {
    block.status != .notExecuted
}

private func executionItem(_ blocks: [WorkoutBlock], prescribed: Bool) -> ScoreItem {
    guard prescribed else { return absent(.execution, .noPrescription) }
    let targeted = blocks.filter { block in
        guard block.kind == .active, let step = block.prescribed else { return false }
        if case .open = step.target { return false }
        return block.status != .noTarget
    }
    var credit = 0.0
    var total = 0.0
    var reasons: [ScoreReason: Double] = [:]
    for block in targeted {
        guard let step = block.prescribed else { continue }
        let weight = isExecuted(block) ? block.seconds : notExecutedSeconds(block, step: step, among: targeted)
        total += weight
        switch block.status {
        case .inTarget:
            credit += weight
        case .incomplete:
            credit += weight * executedFraction(block, step: step)
            reasons[.incompleteStep, default: 0] += weight
        case .notExecuted:
            reasons[.notExecuted, default: 0] += weight
        default:
            reasons[.blocksOffTarget, default: 0] += weight
        }
    }
    guard total > 0 else { return absent(.execution, .noPrescription) }
    let points = credit / total * AnalysisConstants.executionWeight
    let reason = points < AnalysisConstants.executionWeight ? reasons.max { $0.value < $1.value }?.key : nil
    return ScoreItem(part: .execution, points: points, maximum: AnalysisConstants.executionWeight, reason: reason)
}

private func executedFraction(_ block: WorkoutBlock, step: PrescribedStep) -> Double {
    switch step.duration {
    case let .distance(meters) where meters > 0:
        min(block.distance / meters, 1)
    case let .time(seconds) where seconds > 0:
        min(block.seconds / seconds, 1)
    default:
        0
    }
}

private func notExecutedSeconds(_ block: WorkoutBlock, step: PrescribedStep, among targeted: [WorkoutBlock]) -> Double {
    if case let .time(seconds) = step.duration { return seconds }
    let executed = targeted.filter(isExecuted)
    let sameStep = executed.filter { $0.prescribed?.index == step.index }
    let pool = sameStep.isEmpty ? executed : sameStep
    guard !pool.isEmpty else { return 0 }
    return pool.reduce(0) { $0 + $1.seconds } / Double(pool.count)
}

private enum IntentRule {
    case easy
    case heartRateTarget
    case minimumEffort
}

private func intentItem(_ blocks: [WorkoutBlock], zones: HeartRateZones?, prescribed: Bool, hasHeartRate: Bool) -> ScoreItem {
    guard prescribed else { return absent(.intent, .noPrescription) }
    guard hasHeartRate else { return absent(.intent, .noHeartRate) }
    guard let zones, zones.floors.count > AnalysisConstants.easyZoneNumber else { return absent(.intent, .noZones) }
    let ceiling = zones.floors[AnalysisConstants.easyZoneNumber] - 1
    let floor = zones.floors[AnalysisConstants.easyZoneNumber - 1]
    let light = isLightWorkout(blocks, zones: zones, ceiling: ceiling)

    var inRange = 0.0
    var total = 0.0
    var losses: [ScoreReason: Double] = [:]
    for block in blocks where block.kind != .recovery && isExecuted(block) && block.seconds > 0 {
        guard let heartRate = block.avgHeartRate else { continue }
        let verdict: (ok: Bool, reason: ScoreReason)?
        switch block.kind {
        case .warmup, .cooldown:
            verdict = (heartRate <= ceiling, .easyTooHard)
        case .active:
            verdict = activeVerdict(block, heartRate: heartRate, light: light, ceiling: ceiling, floor: floor)
        case .recovery:
            verdict = nil
        }
        guard let verdict else { continue }
        total += block.seconds
        if verdict.ok {
            inRange += block.seconds
        } else {
            losses[verdict.reason, default: 0] += block.seconds
        }
    }
    guard total > 0 else { return absent(.intent, .noPrescription) }
    let points = inRange / total * AnalysisConstants.intentWeight
    let reason = points < AnalysisConstants.intentWeight ? losses.max { $0.value < $1.value }?.key : nil
    return ScoreItem(part: .intent, points: points, maximum: AnalysisConstants.intentWeight, reason: reason)
}

private func activeVerdict(_ block: WorkoutBlock, heartRate: Int, light: Bool, ceiling: Int, floor: Int) -> (ok: Bool, reason: ScoreReason)? {
    if light { return (heartRate <= ceiling, .easyTooHard) }
    guard let step = block.prescribed else { return nil }
    switch step.target {
    case .open:
        return nil
    case .speed:
        return (heartRate >= floor, .hardTooEasy)
    case .heartRateBpm, .heartRatePercentMax, .heartRateZone:
        guard block.status != .noTarget else { return nil }
        return (block.status == .inTarget, .heartRateTargetMissed)
    }
}

private func isLightWorkout(_ blocks: [WorkoutBlock], zones: HeartRateZones, ceiling: Int) -> Bool {
    !blocks.contains { block in
        guard block.kind == .active, let step = block.prescribed else { return false }
        return impliesAboveEasy(step.target, zones: zones, ceiling: ceiling)
    }
}

private func impliesAboveEasy(_ target: StepTarget, zones: HeartRateZones, ceiling: Int) -> Bool {
    switch target {
    case .open:
        false
    case .speed:
        true
    case let .heartRateBpm(low, high):
        (high > 0 ? high : low) > ceiling
    case let .heartRatePercentMax(low, high):
        zones.maxHeartRate.map { (high > 0 ? high : low) * $0 / 100 > ceiling } ?? false
    case let .heartRateZone(number):
        number > AnalysisConstants.easyZoneNumber
    }
}

private func costItem(_ blocks: [WorkoutBlock], previous: [WorkoutOccurrence], hasHeartRate: Bool) -> ScoreItem {
    guard hasHeartRate, let current = efficiency(blocks) else { return absent(.cost, .noHeartRate) }
    let references = previous.compactMap { efficiency($0.blocks) }.sorted()
    guard !references.isEmpty else { return absent(.cost, .noHistory) }
    let reference = median(references)
    guard reference > 0, current.isFinite else { return absent(.cost, .noHistory) }
    let ratio = current / reference - 1
    let share = min(max(AnalysisConstants.costMedianShare + ratio / (2 * AnalysisConstants.costSaturation), 0), 1)
    let reason: ScoreReason? =
        ratio >= AnalysisConstants.costReasonThreshold ? .moreEfficient
        : ratio <= -AnalysisConstants.costReasonThreshold ? .lessEfficient : nil
    return ScoreItem(part: .cost, points: share * AnalysisConstants.costWeight, maximum: AnalysisConstants.costWeight, reason: reason)
}

private func efficiency(_ blocks: [WorkoutBlock]) -> Double? {
    let prescribed = blocks.contains { $0.prescribed != nil }
    let measured = blocks.filter { block in
        (!prescribed || (block.kind == .active && block.prescribed != nil))
            && isExecuted(block) && block.seconds > 0 && (block.avgHeartRate ?? 0) > 0
    }
    let seconds = measured.reduce(0) { $0 + $1.seconds }
    guard seconds > 0 else { return nil }
    let distance = measured.reduce(0) { $0 + $1.distance }
    let heartRate = measured.reduce(0) { $0 + Double($1.avgHeartRate ?? 0) * $1.seconds } / seconds
    return (distance / seconds) / heartRate
}

private func median(_ sorted: [Double]) -> Double {
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}
