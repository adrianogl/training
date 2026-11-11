import TrainingCore
import FITReader

public func hasPrescription(_ structure: WorkoutStructure) -> Bool {
    guard let steps = structure.prescription?.steps else { return false }
    return steps.contains { !isRepeat($0) }
}

public func buildBlocks(_ structure: WorkoutStructure, zones: HeartRateZones?) -> [WorkoutBlock] {
    guard hasPrescription(structure), let prescription = structure.prescription else {
        return freeRunBlocks(structure.laps, zones: zones)
    }
    let expected = unroll(prescription.steps)
    let groups = groupByStep(structure.laps.filter { !isStray($0) })
    var labeler = BlockLabeler()
    var blocks: [WorkoutBlock] = []
    var cursor = 0

    for group in groups {
        guard let match = expected[cursor...].firstIndex(where: { $0.step.index == group.stepIndex }) else {
            let kind = blockKind(group.laps.first?.intensity ?? .active)
            let (ordinal, label) = labeler.next(kind: kind, insideRepeat: false)
            blocks.append(makeBlock(kind: kind, ordinal: ordinal, label: label, prescribed: nil, laps: group.laps, zones: zones))
            continue
        }
        for skipped in expected[cursor..<match] {
            blocks.append(block(for: skipped, laps: [], labeler: &labeler, zones: zones))
        }
        let repetitions = splitAcrossRepetitions(group.laps, step: expected[match].step, available: consecutiveRepetitions(expected, from: match))
        for (offset, laps) in repetitions.enumerated() {
            blocks.append(block(for: expected[match + offset], laps: laps, labeler: &labeler, zones: zones))
        }
        cursor = match + repetitions.count
    }
    for remaining in expected[cursor...] {
        blocks.append(block(for: remaining, laps: [], labeler: &labeler, zones: zones))
    }
    return blocks
}

private struct BlockLabeler {
    private var counters: [String: Int] = [:]

    mutating func next(kind: BlockKind, insideRepeat: Bool) -> (ordinal: Int, label: String) {
        let prefix: String
        switch kind {
        case .warmup: prefix = AnalysisConstants.warmupLabel
        case .cooldown: prefix = AnalysisConstants.cooldownLabel
        case .recovery: prefix = AnalysisConstants.recoveryLabel
        case .active: prefix = insideRepeat ? AnalysisConstants.repeatActiveLabel : AnalysisConstants.activeLabel
        }
        let ordinal = (counters[prefix] ?? 0) + 1
        counters[prefix] = ordinal
        switch kind {
        case .warmup, .cooldown: return (ordinal, prefix)
        case .active, .recovery: return (ordinal, "\(prefix) \(ordinal)")
        }
    }
}

private func isRepeat(_ step: PrescribedStep) -> Bool {
    if case .repeatSteps = step.duration { return true }
    return false
}

private func unroll(_ steps: [PrescribedStep]) -> [ExpectedStep] {
    var expanded: [ExpectedStep] = []
    var firstPosition: [Int: Int] = [:]
    for step in steps {
        guard case let .repeatSteps(fromIndex, count) = step.duration else {
            firstPosition[step.index] = firstPosition[step.index] ?? expanded.count
            expanded.append(ExpectedStep(step: step, insideRepeat: false))
            continue
        }
        guard let start = firstPosition[fromIndex], start < expanded.count else { continue }
        for position in start..<expanded.count {
            expanded[position].insideRepeat = true
        }
        let body = Array(expanded[start...])
        for _ in 1..<max(count, 1) {
            expanded.append(contentsOf: body)
        }
    }
    return expanded
}

private func consecutiveRepetitions(_ expected: [ExpectedStep], from start: Int) -> Int {
    let index = expected[start].step.index
    return expected[start...].prefix { $0.step.index == index }.count
}

private func splitAcrossRepetitions(_ laps: [LapSummary], step: PrescribedStep, available: Int) -> [[LapSummary]] {
    guard available > 1 else { return [laps] }
    var repetitions: [[LapSummary]] = []
    var current: [LapSummary] = []
    for lap in laps {
        current.append(lap)
        if repetitions.count < available - 1, reachesDuration(current, step: step) {
            repetitions.append(current)
            current = []
        }
    }
    if !current.isEmpty { repetitions.append(current) }
    return repetitions
}

private func reachesDuration(_ laps: [LapSummary], step: PrescribedStep) -> Bool {
    switch step.duration {
    case let .distance(meters):
        laps.reduce(0) { $0 + $1.distance } >= meters * AnalysisConstants.completionRatio
    case let .time(seconds):
        laps.reduce(0) { $0 + $1.timerSeconds } >= seconds * AnalysisConstants.completionRatio
    case .open, .repeatSteps:
        true
    }
}

private func isStray(_ lap: LapSummary) -> Bool {
    lap.stepIndex == nil
        && (lap.trigger == AnalysisConstants.sessionEndTrigger || lap.timerSeconds < AnalysisConstants.minimumStraySeconds)
}

private func groupByStep(_ laps: [LapSummary]) -> [LapGroup] {
    var groups: [LapGroup] = []
    for lap in laps {
        if let last = groups.indices.last, lap.stepIndex == nil || groups[last].stepIndex == lap.stepIndex {
            groups[last].laps.append(lap)
        } else {
            groups.append(LapGroup(stepIndex: lap.stepIndex, laps: [lap]))
        }
    }
    return groups
}

private func blockKind(_ intensity: StepIntensity) -> BlockKind {
    switch intensity {
    case .warmup: .warmup
    case .cooldown: .cooldown
    case .recovery, .rest: .recovery
    case .active, .other: .active
    }
}

private func block(for expected: ExpectedStep, laps: [LapSummary], labeler: inout BlockLabeler, zones: HeartRateZones?) -> WorkoutBlock {
    let kind = blockKind(expected.step.intensity)
    let (ordinal, label) = labeler.next(kind: kind, insideRepeat: expected.insideRepeat)
    return makeBlock(kind: kind, ordinal: ordinal, label: label, prescribed: expected.step, laps: laps, zones: zones)
}

private func freeRunBlocks(_ laps: [LapSummary], zones: HeartRateZones?) -> [WorkoutBlock] {
    laps.enumerated().map { offset, lap in
        let ordinal = offset + 1
        return makeBlock(
            kind: .active,
            ordinal: ordinal,
            label: "\(AnalysisConstants.freeRunLabel) \(ordinal)",
            prescribed: nil,
            laps: [lap],
            zones: zones
        )
    }
}

private func makeBlock(
    kind: BlockKind,
    ordinal: Int,
    label: String,
    prescribed: PrescribedStep?,
    laps: [LapSummary],
    zones: HeartRateZones?
) -> WorkoutBlock {
    let seconds = laps.reduce(0) { $0 + $1.timerSeconds }
    let distance = laps.reduce(0) { $0 + $1.distance }
    let avgSpeed = seconds > 0 ? distance / seconds : nil
    let avgHeartRate = weightedHeartRate(laps)
    let maxHeartRate = laps.compactMap(\.maxHeartRate).max()
    return WorkoutBlock(
        kind: kind,
        ordinal: ordinal,
        label: label,
        prescribed: prescribed,
        laps: laps,
        seconds: seconds,
        distance: distance,
        avgSpeed: avgSpeed,
        avgHeartRate: avgHeartRate,
        maxHeartRate: maxHeartRate,
        dominantZone: avgHeartRate.flatMap { zone(of: $0, zones: zones) },
        status: status(prescribed: prescribed, hasLaps: !laps.isEmpty, seconds: seconds, distance: distance, avgSpeed: avgSpeed, avgHeartRate: avgHeartRate, zones: zones)
    )
}

private func weightedHeartRate(_ laps: [LapSummary]) -> Int? {
    let measured = laps.filter { $0.avgHeartRate != nil }
    guard !measured.isEmpty else { return nil }
    let totalSeconds = measured.reduce(0) { $0 + $1.timerSeconds }
    guard totalSeconds > 0 else {
        let sum = measured.reduce(0) { $0 + Double($1.avgHeartRate ?? 0) }
        return Int((sum / Double(measured.count)).rounded())
    }
    let weighted = measured.reduce(0) { $0 + Double($1.avgHeartRate ?? 0) * $1.timerSeconds }
    return Int((weighted / totalSeconds).rounded())
}

func zone(of heartRate: Int, zones: HeartRateZones?) -> Int? {
    guard let floors = zones?.floors else { return nil }
    let zone = floors.filter { $0 <= heartRate }.count
    return zone > 0 ? zone : nil
}

private func status(
    prescribed: PrescribedStep?,
    hasLaps: Bool,
    seconds: Double,
    distance: Double,
    avgSpeed: Double?,
    avgHeartRate: Int?,
    zones: HeartRateZones?
) -> BlockStatus {
    guard let prescribed else { return hasLaps ? .noTarget : .notExecuted }
    guard hasLaps else { return .notExecuted }
    switch prescribed.duration {
    case let .distance(meters) where distance < meters * AnalysisConstants.completionRatio:
        return .incomplete
    case let .time(target) where seconds < target * AnalysisConstants.completionRatio:
        return .incomplete
    default:
        break
    }
    return targetStatus(prescribed.target, avgSpeed: avgSpeed, avgHeartRate: avgHeartRate, zones: zones)
}

func targetStatus(_ target: StepTarget, avgSpeed: Double?, avgHeartRate: Int?, zones: HeartRateZones?) -> BlockStatus {
    switch target {
    case .open:
        return .noTarget
    case let .speed(low, high):
        guard let avgSpeed else { return .noTarget }
        if high > 0, avgSpeed > high { return .faster }
        if avgSpeed < low { return .slower }
        return .inTarget
    case let .heartRateBpm(low, high):
        return heartRateStatus(avgHeartRate, low: Double(low), high: high > 0 ? Double(high) : nil)
    case let .heartRatePercentMax(low, high):
        guard let max = zones?.maxHeartRate else { return .noTarget }
        return heartRateStatus(avgHeartRate, low: Double(low * max) / 100, high: high > 0 ? Double(high * max) / 100 : nil)
    case let .heartRateZone(number):
        guard let floors = zones?.floors, number >= 1, number <= floors.count else { return .noTarget }
        let high = number < floors.count ? Double(floors[number] - 1) : nil
        return heartRateStatus(avgHeartRate, low: Double(floors[number - 1]), high: high)
    }
}

private func heartRateStatus(_ heartRate: Int?, low: Double, high: Double?) -> BlockStatus {
    guard let heartRate else { return .noTarget }
    let value = Double(heartRate)
    if let high, value > high { return .aboveTarget }
    if value < low { return .belowTarget }
    return .inTarget
}
