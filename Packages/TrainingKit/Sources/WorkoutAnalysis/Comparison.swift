public func compare(current: WorkoutOccurrence, previous: [WorkoutOccurrence]) -> WorkoutComparison? {
    guard !previous.isEmpty else { return nil }
    let earlier = previous.sorted { $0.day > $1.day }.prefix(AnalysisConstants.maxComparisons)
    let shown = [current] + earlier
    let currentLabels = current.blocks.map(\.label)
    let sameStructure = earlier.allSatisfy { $0.blocks.map(\.label) == currentLabels }
    let labels = uniqueLabels(currentLabels).filter { label in
        earlier.allSatisfy { occurrence in occurrence.blocks.contains { $0.label == label } }
    }
    let blocks = labels.map { label in
        BlockComparison(label: label, values: Dictionary(uniqueKeysWithValues: shown.compactMap { occurrence in
            occurrence.blocks.first { $0.label == label }.map {
                (occurrence.activityId, BlockValue(speed: $0.avgSpeed, heartRate: $0.avgHeartRate, status: $0.status))
            }
        }))
    }
    let oldest = shown[shown.count - 1]
    let currentActive = activeBlocks(current, labels: labels)
    let oldestActive = activeBlocks(oldest, labels: labels)
    return WorkoutComparison(
        occurrences: shown.map(\.activityId),
        blocks: blocks,
        sameStructure: sameStructure,
        activeSpeedDelta: difference(weightedSpeed(currentActive), weightedSpeed(oldestActive)),
        activeHeartRateDelta: difference(weightedHeartRate(currentActive), weightedHeartRate(oldestActive))
    )
}

private func uniqueLabels(_ labels: [String]) -> [String] {
    var seen: Set<String> = []
    return labels.filter { seen.insert($0).inserted }
}

private func activeBlocks(_ occurrence: WorkoutOccurrence, labels: [String]) -> [WorkoutBlock] {
    labels.compactMap { label in occurrence.blocks.first { $0.label == label } }.filter { $0.kind == .active }
}

private func weightedSpeed(_ blocks: [WorkoutBlock]) -> Double? {
    let seconds = blocks.reduce(0) { $0 + $1.seconds }
    guard seconds > 0 else { return nil }
    return blocks.reduce(0) { $0 + $1.distance } / seconds
}

private func weightedHeartRate(_ blocks: [WorkoutBlock]) -> Double? {
    let measured = blocks.filter { $0.avgHeartRate != nil && $0.seconds > 0 }
    let seconds = measured.reduce(0) { $0 + $1.seconds }
    guard seconds > 0 else { return nil }
    return measured.reduce(0) { $0 + Double($1.avgHeartRate ?? 0) * $1.seconds } / seconds
}

private func difference(_ current: Double?, _ baseline: Double?) -> Double? {
    guard let current, let baseline else { return nil }
    return current - baseline
}
