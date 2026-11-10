import FITReader

public func assess(_ blocks: [WorkoutBlock], context: AssessmentContext) -> WorkoutAssessment {
    let findings = blockInTarget(blocks)
        + steadyPace(blocks, kilometers: context.kilometers)
        + lowerHeartRateThanBefore(blocks, previous: context.previous)
        + goodRecovery(blocks)
        + blockOffTarget(blocks)
        + stepIncomplete(blocks)
        + paceFade(blocks, kilometers: context.kilometers)
        + cardiacDrift(blocks, kilometers: context.kilometers)
        + zoneAboveTarget(blocks)
        + hardOnLowReadiness(blocks, readiness: context.readinessScore)
        + highAcuteChronic(context.acuteChronic)
    return WorkoutAssessment(
        positives: findings.filter { $0.group == .positive },
        negatives: findings.filter { $0.group == .negative },
        attention: findings.filter { $0.group == .attention }
    )
}

private func blockInTarget(_ blocks: [WorkoutBlock]) -> [Finding] {
    let targeted = blocks.filter { $0.kind == .active && hasTarget($0) }
    let inTarget = targeted.filter { $0.status == .inTarget }.count
    guard inTarget > 0 else { return [] }
    return [Finding(group: .positive, kind: .blockInTarget, blockOrdinal: nil, facts: [
        FindingFact.inTarget: Double(inTarget),
        FindingFact.total: Double(targeted.count),
    ])]
}

private func steadyPace(_ blocks: [WorkoutBlock], kilometers: BlockKilometers) -> [Finding] {
    eligibleForLapRules(blocks, kilometers: kilometers).compactMap { position, laps in
        let paces = laps.map(pace)
        guard let fastest = paces.min(), let slowest = paces.max() else { return nil }
        let spread = slowest - fastest
        guard spread <= AnalysisConstants.steadyPaceSpread else { return nil }
        return Finding(group: .positive, kind: .steadyPace, blockOrdinal: position, facts: [FindingFact.spread: spread])
    }
}

private func paceFade(_ blocks: [WorkoutBlock], kilometers: BlockKilometers) -> [Finding] {
    eligibleForLapRules(blocks, kilometers: kilometers).compactMap { position, laps in
        let paces = laps.map(pace)
        guard let last = paces.last else { return nil }
        let fade = last - median(paces)
        guard fade >= AnalysisConstants.fadeThreshold else { return nil }
        return Finding(group: .negative, kind: .paceFade, blockOrdinal: position, facts: [FindingFact.fade: fade])
    }
}

private func cardiacDrift(_ blocks: [WorkoutBlock], kilometers: BlockKilometers) -> [Finding] {
    eligibleForLapRules(blocks, kilometers: kilometers).compactMap { position, laps in
        let third = max(1, laps.count / 3)
        let first = Array(laps.prefix(third))
        let final = Array(laps.suffix(third))
        guard let fromHR = meanHeartRate(first), let toHR = meanHeartRate(final), fromHR > 0 else { return nil }
        let rise = toHR / fromHR - 1
        let speedChange = abs(meanSpeed(final) / meanSpeed(first) - 1)
        guard rise >= AnalysisConstants.driftThreshold, speedChange <= AnalysisConstants.driftMaxSpeedChange else { return nil }
        return Finding(group: .attention, kind: .cardiacDrift, blockOrdinal: position, facts: [
            FindingFact.rise: rise,
            FindingFact.fromHR: fromHR,
            FindingFact.toHR: toHR,
        ])
    }
}

private func goodRecovery(_ blocks: [WorkoutBlock]) -> [Finding] {
    blocks.indices.dropFirst().compactMap { position in
        let recovery = blocks[position]
        let active = blocks[position - 1]
        guard recovery.kind == .recovery, active.kind == .active,
              let peak = active.maxHeartRate, let recovered = recovery.avgHeartRate else { return nil }
        let drop = peak - recovered
        guard drop >= AnalysisConstants.goodRecoveryDrop else { return nil }
        return Finding(group: .positive, kind: .goodRecovery, blockOrdinal: position, facts: [FindingFact.drop: Double(drop)])
    }
}

private func lowerHeartRateThanBefore(_ blocks: [WorkoutBlock], previous: [[WorkoutBlock]]) -> [Finding] {
    blocks.enumerated().compactMap { position, block in
        guard block.kind == .active, let heartRate = block.avgHeartRate, let speed = block.avgSpeed,
              let before = previous.lazy.compactMap({ $0.first { $0.label == block.label } }).first,
              let beforeHeartRate = before.avgHeartRate, let beforeSpeed = before.avgSpeed, beforeSpeed > 0 else { return nil }
        let delta = beforeHeartRate - heartRate
        guard delta >= AnalysisConstants.lowerHeartRateMargin,
              abs(speed / beforeSpeed - 1) <= AnalysisConstants.sameSpeedTolerance else { return nil }
        return Finding(group: .positive, kind: .lowerHeartRateThanBefore, blockOrdinal: position, facts: [FindingFact.delta: Double(delta)])
    }
}

private func blockOffTarget(_ blocks: [WorkoutBlock]) -> [Finding] {
    let offTarget: Set<BlockStatus> = [.faster, .slower, .aboveTarget, .belowTarget]
    return blocks.enumerated().compactMap { position, block in
        guard offTarget.contains(block.status) else { return nil }
        var facts: [String: Double] = [:]
        facts[FindingFact.speed] = block.avgSpeed
        facts[FindingFact.heartRate] = block.avgHeartRate.map(Double.init)
        switch block.prescribed?.target {
        case let .speed(low, high):
            facts[FindingFact.targetLow] = low > 0 ? low : nil
            facts[FindingFact.targetHigh] = high > 0 ? high : nil
        case let .heartRateBpm(low, high):
            facts[FindingFact.targetLow] = low > 0 ? Double(low) : nil
            facts[FindingFact.targetHigh] = high > 0 ? Double(high) : nil
        default:
            break
        }
        return Finding(group: .negative, kind: .blockOffTarget, blockOrdinal: position, facts: facts)
    }
}

private func stepIncomplete(_ blocks: [WorkoutBlock]) -> [Finding] {
    blocks.enumerated().compactMap { position, block in
        guard block.status == .incomplete || block.status == .notExecuted else { return nil }
        var facts = [FindingFact.distance: block.distance, FindingFact.seconds: block.seconds]
        switch block.prescribed?.duration {
        case let .distance(meters): facts[FindingFact.targetDistance] = meters
        case let .time(seconds): facts[FindingFact.targetSeconds] = seconds
        default: break
        }
        return Finding(group: .negative, kind: .stepIncomplete, blockOrdinal: position, facts: facts)
    }
}

private func zoneAboveTarget(_ blocks: [WorkoutBlock]) -> [Finding] {
    blocks.enumerated().compactMap { position, block in
        guard block.kind != .active, let zone = block.dominantZone, zone >= AnalysisConstants.easyBlockZoneLimit else { return nil }
        return Finding(group: .attention, kind: .zoneAboveTarget, blockOrdinal: position, facts: [FindingFact.zone: Double(zone)])
    }
}

private func hardOnLowReadiness(_ blocks: [WorkoutBlock], readiness: Int?) -> [Finding] {
    guard let readiness, readiness < AnalysisConstants.lowReadiness else { return [] }
    let isHard = blocks.contains { block in
        block.kind == .active && (hasTarget(block) || (block.dominantZone ?? 0) >= AnalysisConstants.hardZone)
    }
    guard isHard else { return [] }
    return [Finding(group: .attention, kind: .hardOnLowReadiness, blockOrdinal: nil, facts: [FindingFact.readiness: Double(readiness)])]
}

private func highAcuteChronic(_ ratio: Double?) -> [Finding] {
    guard let ratio, ratio > AnalysisConstants.highAcuteChronic else { return [] }
    return [Finding(group: .attention, kind: .highAcuteChronic, blockOrdinal: nil, facts: [FindingFact.ratio: ratio])]
}

private func hasTarget(_ block: WorkoutBlock) -> Bool {
    guard let target = block.prescribed?.target else { return false }
    return target != .open
}

private func eligibleForLapRules(_ blocks: [WorkoutBlock], kilometers: BlockKilometers) -> [(position: Int, laps: [LapSummary])] {
    blocks.enumerated().compactMap { position, block in
        guard block.kind == .active else { return nil }
        let laps = kilometers[position]?.flatMap(\.laps) ?? block.laps
        let full = laps.filter { $0.distance >= AnalysisConstants.fullLapMinimumDistance && lapSpeed($0) > 0 }
        return full.count >= AnalysisConstants.minimumFullLaps ? (position, full) : nil
    }
}

private func lapSpeed(_ lap: LapSummary) -> Double {
    if let speed = lap.avgSpeed { return speed }
    return lap.timerSeconds > 0 ? lap.distance / lap.timerSeconds : 0
}

private func pace(_ lap: LapSummary) -> Double {
    1000 / lapSpeed(lap)
}

private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}

private func meanHeartRate(_ laps: [LapSummary]) -> Double? {
    let values = laps.compactMap(\.avgHeartRate)
    guard !values.isEmpty else { return nil }
    return Double(values.reduce(0, +)) / Double(values.count)
}

private func meanSpeed(_ laps: [LapSummary]) -> Double {
    laps.reduce(0) { $0 + lapSpeed($1) } / Double(laps.count)
}
