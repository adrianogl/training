public func aboveExpected(_ blocks: [WorkoutBlock], previous: [[WorkoutBlock]]) -> [AboveExpectedSignal] {
    [heartRateAtPace(blocks, previous: previous), recoveryDrop(blocks, previous: previous)].compactMap { $0 }
}

private struct ActiveEffort {
    let speed: Double
    let heartRate: Double
}

private func activeEffort(_ blocks: [WorkoutBlock]) -> ActiveEffort? {
    let prescribed = blocks.contains { $0.prescribed != nil }
    let measured = blocks.filter { block in
        block.kind == .active && (!prescribed || block.prescribed != nil)
            && block.status != .notExecuted && block.seconds > 0 && (block.avgHeartRate ?? 0) > 0
    }
    let seconds = measured.reduce(0) { $0 + $1.seconds }
    guard seconds > 0 else { return nil }
    let distance = measured.reduce(0) { $0 + $1.distance }
    let heartRate = measured.reduce(0) { $0 + Double($1.avgHeartRate ?? 0) * $1.seconds } / seconds
    return ActiveEffort(speed: distance / seconds, heartRate: heartRate)
}

private func heartRateAtPace(_ blocks: [WorkoutBlock], previous: [[WorkoutBlock]]) -> AboveExpectedSignal? {
    guard let today = activeEffort(blocks) else { return nil }
    let earlier = previous.compactMap(activeEffort)
    guard earlier.count >= AnalysisConstants.aboveExpectedMinimumComparisons else { return nil }
    let beforeSpeed = earlier.reduce(0) { $0 + $1.speed } / Double(earlier.count)
    let beforeHeartRate = (earlier.reduce(0) { $0 + $1.heartRate } / Double(earlier.count)).rounded()
    let todayHeartRate = today.heartRate.rounded()
    guard today.speed >= beforeSpeed * (1 - AnalysisConstants.sameSpeedTolerance),
          beforeHeartRate - todayHeartRate >= AnalysisConstants.aboveExpectedHeartRateMargin else { return nil }
    return AboveExpectedSignal(kind: .heartRateAtPace, before: beforeHeartRate, today: todayHeartRate, compared: earlier.count)
}

private func averageRecoveryDrop(_ blocks: [WorkoutBlock]) -> Double? {
    let drops = blocks.indices.dropFirst().compactMap { position -> Int? in
        let recovery = blocks[position]
        let active = blocks[position - 1]
        guard recovery.kind == .recovery, active.kind == .active, let peak = active.maxHeartRate, let recovered = recovery.avgHeartRate else { return nil }
        return peak - recovered
    }
    guard !drops.isEmpty else { return nil }
    return Double(drops.reduce(0, +)) / Double(drops.count)
}

private func recoveryDrop(_ blocks: [WorkoutBlock], previous: [[WorkoutBlock]]) -> AboveExpectedSignal? {
    guard let today = averageRecoveryDrop(blocks)?.rounded() else { return nil }
    let earlier = previous.compactMap(averageRecoveryDrop)
    guard earlier.count >= AnalysisConstants.aboveExpectedMinimumComparisons else { return nil }
    let before = (earlier.reduce(0, +) / Double(earlier.count)).rounded()
    guard today >= Double(AnalysisConstants.goodRecoveryDrop),
          today - before >= AnalysisConstants.aboveExpectedRecoveryMargin else { return nil }
    return AboveExpectedSignal(kind: .recoveryDrop, before: before, today: today, compared: earlier.count)
}
