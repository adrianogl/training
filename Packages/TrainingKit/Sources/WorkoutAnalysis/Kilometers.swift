import FITReader

public func kilometerSplits(_ samples: [FITSample], zones: HeartRateZones?) -> [WorkoutBlock] {
    let points = trackPoints(samples)
    guard let first = points.first else { return [] }
    return split(points, start: first.t, kind: .active, prescribed: nil, zones: zones)
}

public func kilometerSplits(of blocks: [WorkoutBlock], samples: [FITSample], zones: HeartRateZones?) -> BlockKilometers {
    let points = trackPoints(samples)
    var result: BlockKilometers = [:]
    for (position, block) in blocks.enumerated() where opensInKilometers(block) {
        guard let firstLap = block.laps.first else { continue }
        let end = blocks[(position + 1)...].lazy.compactMap { $0.laps.first?.startOffset }.first ?? .infinity
        let window = points.filter { $0.t >= firstLap.startOffset && $0.t <= end }
        let rows = split(window, start: firstLap.startOffset, kind: block.kind, prescribed: block.prescribed, zones: zones)
        if !rows.isEmpty { result[position] = rows }
    }
    return result
}

private func opensInKilometers(_ block: WorkoutBlock) -> Bool {
    block.distance >= AnalysisConstants.splitBlockMinimumDistance || block.seconds >= AnalysisConstants.splitBlockMinimumSeconds
}

private func trackPoints(_ samples: [FITSample]) -> [TrackPoint] {
    var integrated = 0.0
    var previous: FITSample?
    return samples.sorted { $0.t < $1.t }.map { sample in
        if let previous, let speed = previous.speed {
            integrated += speed * max(0, sample.t - previous.t)
        }
        previous = sample
        return TrackPoint(t: sample.t, distance: sample.distance ?? integrated, heartRate: sample.heartRate)
    }
}

private func split(_ points: [TrackPoint], start: Double, kind: BlockKind, prescribed: PrescribedStep?, zones: HeartRateZones?) -> [WorkoutBlock] {
    guard let first = points.first, let last = points.last else { return [] }
    var rows: [WorkoutBlock] = []
    var startTime = start
    var startDistance = first.distance
    var previousTime = start
    var previousDistance = first.distance
    var seconds = 0.0
    var heartRates: [Int] = []
    func close(at point: TrackPoint) {
        rows.append(kilometer(
            ordinal: rows.count + 1,
            kind: kind,
            start: startTime,
            seconds: seconds,
            distance: point.distance - startDistance,
            heartRates: heartRates,
            prescribed: prescribed,
            zones: zones
        ))
    }
    for point in points {
        let interval = point.t - previousTime
        if !isPause(interval: interval, distance: point.distance - previousDistance) { seconds += max(0, interval) }
        previousTime = point.t
        previousDistance = point.distance
        if let heartRate = point.heartRate { heartRates.append(heartRate) }
        guard point.distance - startDistance >= AnalysisConstants.kilometerSplitDistance else { continue }
        close(at: point)
        startTime = point.t
        startDistance = point.distance
        seconds = 0
        heartRates = []
    }
    if last.distance - startDistance >= AnalysisConstants.minimumPartialSplit {
        close(at: last)
    }
    return rows
}

private func isPause(interval: Double, distance: Double) -> Bool {
    interval > AnalysisConstants.pauseGapSeconds && distance < interval * AnalysisConstants.pauseMaximumSpeed
}

private func kilometer(
    ordinal: Int,
    kind: BlockKind,
    start: Double,
    seconds: Double,
    distance: Double,
    heartRates: [Int],
    prescribed: PrescribedStep?,
    zones: HeartRateZones?
) -> WorkoutBlock {
    let speed = seconds > 0 ? distance / seconds : nil
    let average = heartRates.isEmpty ? nil : Int((Double(heartRates.reduce(0, +)) / Double(heartRates.count)).rounded())
    let maximum = heartRates.max()
    let lap = LapSummary(startOffset: start, timerSeconds: seconds, distance: distance, avgSpeed: speed, avgHeartRate: average, maxHeartRate: maximum)
    return WorkoutBlock(
        kind: kind,
        ordinal: ordinal,
        label: "\(AnalysisConstants.kilometerLabel) \(ordinal)",
        prescribed: prescribed,
        laps: [lap],
        seconds: seconds,
        distance: distance,
        avgSpeed: speed,
        avgHeartRate: average,
        maxHeartRate: maximum,
        dominantZone: average.flatMap { zone(of: $0, zones: zones) },
        status: prescribed.map { targetStatus($0.target, avgSpeed: speed, avgHeartRate: average, zones: zones) } ?? .noTarget
    )
}
