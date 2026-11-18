import FITReader
import TrainingCore

public func assess(_ blocks: [WorkoutBlock], context: AssessmentContext) -> WorkoutAssessment {
    let findings = blockInTarget(blocks)
        + steadyPace(blocks, kilometers: context.kilometers)
        + lowerHeartRateThanBefore(blocks, previous: context.previous)
        + goodRecovery(blocks)
        + blockOffTarget(blocks)
        + stepIncomplete(blocks, context: context)
        + paceFade(blocks, kilometers: context.kilometers, weather: context.weather)
        + elevationPace(blocks, kilometers: context.kilometers)
        + weatherSlower(blocks, weather: context.weather)
        + cardiacDrift(blocks, kilometers: context.kilometers, weather: context.weather)
        + zoneAboveTarget(blocks, weather: context.weather)
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
        let paces = laps.map(levelPace)
        guard let fastest = paces.min(), let slowest = paces.max() else { return nil }
        let spread = slowest - fastest
        guard spread <= AnalysisConstants.steadyPaceSpread else { return nil }
        var facts = [
            FindingFact.spread: spread,
            FindingFact.fastestPace: fastest,
            FindingFact.slowestPace: slowest,
        ]
        if laps.contains(where: hasElevation) { facts[FindingFact.flatAdjusted] = 1 }
        return Finding(group: .positive, kind: .steadyPace, blockOrdinal: position, facts: facts)
    }
}

private func paceFade(_ blocks: [WorkoutBlock], kilometers: BlockKilometers, weather: WeatherEffect?) -> [Finding] {
    eligibleForLapRules(blocks, kilometers: kilometers).compactMap { position, laps in
        let paces = laps.map(levelPace)
        guard let last = paces.last, let lastLap = laps.last else { return nil }
        let middle = median(paces)
        let fade = last - middle
        guard fade >= AnalysisConstants.fadeThreshold else { return nil }
        var facts = [
            FindingFact.fade: fade,
            FindingFact.lastPace: last,
            FindingFact.medianPace: middle,
        ]
        if laps.contains(where: hasElevation) {
            facts[FindingFact.flatAdjusted] = 1
            facts[FindingFact.pace] = pace(lastLap)
            facts[FindingFact.lastClimb] = lastLap.climb ?? 0
        }
        if let weather, weather.isHeat, weather.paceFactor >= RunWeatherConstants.fadeHeatFactor {
            facts.merge(weatherFacts(weather)) { current, _ in current }
        }
        return Finding(group: .negative, kind: .paceFade, blockOrdinal: position, facts: facts)
    }
}

private func elevationPace(_ blocks: [WorkoutBlock], kilometers: BlockKilometers) -> [Finding] {
    var findings: [Finding] = []
    for (position, rows) in kilometers.sorted(by: { $0.key < $1.key }) where blocks.indices.contains(position) && blocks[position].kind == .active {
        let startKm = blocks[..<position].reduce(0) { $0 + $1.distance } / AnalysisConstants.metersPerKilometer
        var segment: (kind: FindingKind, from: Int, laps: [LapSummary])?
        func close() {
            guard let current = segment else { return }
            findings.append(elevationFinding(current.kind, position: position, from: current.from, laps: current.laps))
            segment = nil
        }
        for (index, row) in rows.enumerated() {
            guard let lap = row.laps.first, lap.distance >= AnalysisConstants.fullLapMinimumDistance, let kind = elevationKind(lap) else {
                close()
                continue
            }
            let kilometer = Int(startKm.rounded()) + index + 1
            if let current = segment, current.kind == kind {
                segment?.laps.append(lap)
            } else {
                close()
                segment = (kind, kilometer, [lap])
            }
        }
        close()
    }
    return findings
}

private func elevationKind(_ lap: LapSummary) -> FindingKind? {
    guard hasElevation(lap), let level = flatPace(lap) else { return nil }
    let effect = pace(lap) - level
    if effect >= AnalysisConstants.elevationEffectSeconds { return .climbSlower }
    if effect <= -AnalysisConstants.elevationEffectSeconds { return .descentFaster }
    return nil
}

private func elevationFinding(_ kind: FindingKind, position: Int, from: Int, laps: [LapSummary]) -> Finding {
    let distance = laps.reduce(0) { $0 + $1.distance }
    let seconds = laps.reduce(0) { $0 + $1.distance * pace($1) } / AnalysisConstants.metersPerKilometer
    let level = laps.reduce(0) { $0 + $1.distance * levelPace($1) } / AnalysisConstants.metersPerKilometer
    return Finding(group: .positive, kind: kind, blockOrdinal: position, facts: [
        FindingFact.fromKilometer: Double(from),
        FindingFact.toKilometer: Double(from + laps.count - 1),
        FindingFact.climb: laps.reduce(0) { $0 + ($1.climb ?? 0) },
        FindingFact.descent: laps.reduce(0) { $0 + ($1.descent ?? 0) },
        FindingFact.pace: seconds / (distance / AnalysisConstants.metersPerKilometer),
        FindingFact.flatPace: level / (distance / AnalysisConstants.metersPerKilometer),
    ])
}

private func levelPace(_ lap: LapSummary) -> Double {
    flatPace(lap) ?? pace(lap)
}

private func cardiacDrift(_ blocks: [WorkoutBlock], kilometers: BlockKilometers, weather: WeatherEffect?) -> [Finding] {
    let expected = weather.map { $0.isHeat && $0.paceFactor >= RunWeatherConstants.driftHeatFactor } ?? false
    return eligibleForLapRules(blocks, kilometers: kilometers).compactMap { position, laps in
        let third = max(1, laps.count / 3)
        let first = Array(laps.prefix(third))
        let final = Array(laps.suffix(third))
        guard let fromHR = meanHeartRate(first), let toHR = meanHeartRate(final), fromHR > 0 else { return nil }
        let rise = toHR / fromHR - 1
        let speedChange = abs(meanSpeed(final) / meanSpeed(first) - 1)
        guard rise >= AnalysisConstants.driftThreshold, speedChange <= AnalysisConstants.driftMaxSpeedChange else { return nil }
        var facts = [
            FindingFact.rise: rise,
            FindingFact.fromHR: fromHR,
            FindingFact.toHR: toHR,
        ]
        if expected, let weather { facts.merge(weatherFacts(weather)) { current, _ in current } }
        return Finding(group: expected ? .positive : .attention, kind: .cardiacDrift, blockOrdinal: position, facts: facts)
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
        return Finding(group: .positive, kind: .goodRecovery, blockOrdinal: position, facts: [
            FindingFact.drop: Double(drop),
            FindingFact.peak: Double(peak),
            FindingFact.recovered: Double(recovered),
        ])
    }
}

private func lowerHeartRateThanBefore(_ blocks: [WorkoutBlock], previous: [[WorkoutBlock]]) -> [Finding] {
    blocks.enumerated().compactMap { position, block in
        guard block.kind == .active, let heartRate = block.avgHeartRate, let speed = block.weatherSpeed,
              let before = previous.lazy.compactMap({ $0.first { $0.label == block.label } }).first,
              let beforeHeartRate = before.avgHeartRate, let beforeSpeed = before.weatherSpeed, beforeSpeed > 0 else { return nil }
        let delta = beforeHeartRate - heartRate
        guard delta >= AnalysisConstants.lowerHeartRateMargin,
              abs(speed / beforeSpeed - 1) <= AnalysisConstants.sameSpeedTolerance else { return nil }
        return Finding(group: .positive, kind: .lowerHeartRateThanBefore, blockOrdinal: position, facts: [
            FindingFact.delta: Double(delta),
            FindingFact.heartRate: Double(heartRate),
            FindingFact.beforeHeartRate: Double(beforeHeartRate),
            FindingFact.speed: speed,
        ])
    }
}

private func blockOffTarget(_ blocks: [WorkoutBlock]) -> [Finding] {
    let offTarget: Set<BlockStatus> = [.faster, .slower, .aboveTarget, .belowTarget]
    let highestRecovery = blocks.filter { $0.kind == .recovery }.compactMap(\.avgHeartRate).max()
    return blocks.enumerated().compactMap { position, block in
        guard offTarget.contains(block.status) else { return nil }
        var facts: [String: Double] = [:]
        facts[FindingFact.speed] = block.avgSpeed
        facts[FindingFact.heartRate] = block.avgHeartRate.map(Double.init)
        if position > 0, blocks[position - 1].kind == .recovery, let recovery = blocks[position - 1].avgHeartRate {
            facts[FindingFact.recoveryHeartRate] = Double(recovery)
            facts[FindingFact.recoveryHighest] = recovery == highestRecovery ? 1 : 0
        }
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

private func stepIncomplete(_ blocks: [WorkoutBlock], context: AssessmentContext) -> [Finding] {
    blocks.enumerated().compactMap { position, block in
        guard block.status == .incomplete || block.status == .notExecuted else { return nil }
        var facts = [FindingFact.distance: block.distance, FindingFact.seconds: block.seconds]
        switch block.prescribed?.duration {
        case let .distance(meters): facts[FindingFact.targetDistance] = meters
        case let .time(seconds): facts[FindingFact.targetSeconds] = seconds
        default: break
        }
        if block.status == .incomplete, block.kind == .active {
            facts.merge(slowdownFacts(context.kilometers[position] ?? [])) { current, _ in current }
            facts.merge(pauseFacts(context.continuity)) { current, _ in current }
            if let readiness = context.readinessScore, readiness < AnalysisConstants.lowReadiness {
                facts[FindingFact.readiness] = Double(readiness)
            }
            if let ratio = context.acuteChronic, ratio > AnalysisConstants.highAcuteChronic {
                facts[FindingFact.ratio] = ratio
            }
        }
        return Finding(group: .negative, kind: .stepIncomplete, blockOrdinal: position, facts: facts)
    }
}

private func slowdownFacts(_ kilometers: [WorkoutBlock]) -> [String: Double] {
    let rows = kilometers.enumerated().compactMap { index, row -> (kilometer: Int, lap: LapSummary)? in
        guard let lap = row.laps.first, lap.distance >= AnalysisConstants.fullLapMinimumDistance, lapSpeed(lap) > 0 else { return nil }
        return (index + 1, lap)
    }
    let baseline = AnalysisConstants.baselineKilometers
    guard rows.count > baseline else { return [:] }
    let paces = rows.map { levelPace($0.lap) }
    let reference = paces.prefix(baseline).reduce(0, +) / Double(baseline)
    var facts: [String: Double] = [:]
    for index in baseline ..< rows.count {
        let tail = paces[index...]
        let slowdown = tail.reduce(0, +) / Double(tail.count) - reference
        guard paces[index] - reference >= AnalysisConstants.fadeThreshold, slowdown >= AnalysisConstants.fadeThreshold else { continue }
        facts[FindingFact.fadeKilometer] = Double(rows[index].kilometer)
        facts[FindingFact.slowdown] = slowdown
        break
    }
    guard rows.count >= baseline * 2,
          let start = meanHeartRate(rows.prefix(baseline).map(\.lap)),
          let end = meanHeartRate(rows.suffix(baseline).map(\.lap)),
          end - start >= AnalysisConstants.heartRateRiseMinimum else { return facts }
    facts[FindingFact.heartRateRise] = end - start
    return facts
}

private func pauseFacts(_ continuity: RunContinuity?) -> [String: Double] {
    guard let continuity, let first = continuity.pauses.first else { return [:] }
    return [
        FindingFact.pauseCount: Double(continuity.pauses.count),
        FindingFact.pauseKilometer: first.startMeters / AnalysisConstants.metersPerKilometer,
        FindingFact.pauseSeconds: continuity.pauses.reduce(0) { $0 + $1.seconds },
    ]
}

private func zoneAboveTarget(_ blocks: [WorkoutBlock], weather: WeatherEffect?) -> [Finding] {
    let hot = weather.map { $0.isHeat && $0.paceFactor >= RunWeatherConstants.zoneHeatFactor } ?? false
    let limit = AnalysisConstants.easyBlockZoneLimit + (hot ? 1 : 0)
    return blocks.enumerated().compactMap { position, block in
        guard block.kind == .warmup || block.kind == .cooldown, let zone = block.dominantZone, zone >= limit else { return nil }
        var facts = [FindingFact.zone: Double(zone)]
        facts[FindingFact.speed] = block.avgSpeed
        facts[FindingFact.heartRate] = block.avgHeartRate.map(Double.init)
        return Finding(group: .attention, kind: .zoneAboveTarget, blockOrdinal: position, facts: facts)
    }
}

private func weatherSlower(_ blocks: [WorkoutBlock], weather: WeatherEffect?) -> [Finding] {
    let rescued = blocks.filter { $0.weatherRescued == true && $0.seconds > 0 && $0.distance > 0 }
    guard let weather, !rescued.isEmpty else { return [] }
    let seconds = rescued.reduce(0) { $0 + $1.seconds }
    let kilometers = rescued.reduce(0) { $0 + $1.distance } / AnalysisConstants.metersPerKilometer
    let pace = seconds / kilometers
    var facts = weatherFacts(weather)
    facts[FindingFact.pace] = pace
    facts[FindingFact.mildPace] = WeatherAdjustment.mildPace(pace, effect: weather)
    facts[FindingFact.count] = Double(rescued.count)
    return [Finding(group: .positive, kind: .weatherSlower, blockOrdinal: nil, facts: facts)]
}

func weatherFacts(_ weather: WeatherEffect) -> [String: Double] {
    var facts = [
        FindingFact.temperature: weather.weather.temperature,
        FindingFact.weatherFactor: weather.paceFactor,
    ]
    facts[FindingFact.dewPoint] = weather.weather.dewPoint
    if weather.isCold { facts[FindingFact.cold] = 1 }
    return facts
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
