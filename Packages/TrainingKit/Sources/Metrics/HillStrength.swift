import FITReader

private enum GradeClass {
    case up, flat, down

    init(_ grade: Double) {
        if grade > RunMetricsConstants.flatMaximumGrade {
            self = .up
        } else if grade < -RunMetricsConstants.flatMaximumGrade {
            self = .down
        } else {
            self = .flat
        }
    }
}

private struct GradeSegment {
    var kind: GradeClass
    var length = 0.0
    var climb = 0.0
    var samples: [FITSample] = []

    var grade: Double { length > 0 ? climb / length : 0 }
}

private struct GradePoint {
    let sample: FITSample
    let distance: Double
    let altitude: Double
}

private func gradeRuns(_ s: [FITSample]) -> [[GradePoint]] {
    var runs: [[GradePoint]] = []
    var current: [GradePoint] = []
    for sample in s {
        guard let distance = sample.distance, let altitude = sample.altitude else {
            if !current.isEmpty { runs.append(current) }
            current = []
            continue
        }
        if let last = current.last, distance <= last.distance {
            runs.append(current)
            current = []
        }
        current.append(GradePoint(sample: sample, distance: distance, altitude: altitude))
    }
    if !current.isEmpty { runs.append(current) }
    return runs
}

private func windowGrade(_ points: [GradePoint], at index: Int) -> Double {
    let half = RunMetricsConstants.gradeWindowLength / 2
    var low = index
    while low > 0, points[index].distance - points[low - 1].distance <= half { low -= 1 }
    var high = index
    while high < points.count - 1, points[high + 1].distance - points[index].distance <= half { high += 1 }
    let length = points[high].distance - points[low].distance
    return length > 0 ? (points[high].altitude - points[low].altitude) / length : 0
}

private func rawGrade(_ points: [GradePoint], at index: Int) -> Double {
    (points[index].altitude - points[index - 1].altitude) / (points[index].distance - points[index - 1].distance)
}

private func deltaKinds(_ points: [GradePoint]) -> [GradeClass] {
    var kinds = points.indices.map { $0 == 0 ? GradeClass.flat : GradeClass(windowGrade(points, at: $0)) }
    func trim(_ range: Range<Int>, _ kind: GradeClass) {
        var start = range.lowerBound
        var end = range.upperBound - 1
        while start <= end, GradeClass(rawGrade(points, at: start)) != kind {
            kinds[start] = GradeClass(rawGrade(points, at: start))
            start += 1
        }
        while end >= start, GradeClass(rawGrade(points, at: end)) != kind {
            kinds[end] = GradeClass(rawGrade(points, at: end))
            end -= 1
        }
    }
    var index = 1
    while index < points.count {
        let kind = kinds[index]
        var end = index
        while end + 1 < points.count, kinds[end + 1] == kind { end += 1 }
        if kind != .flat { trim(index..<(end + 1), kind) }
        index = end + 1
    }
    return kinds
}

private func gradeSegments(_ s: [FITSample]) -> [GradeSegment] {
    var segments: [GradeSegment] = []
    for points in gradeRuns(s) {
        let kinds = deltaKinds(points)
        var current: GradeSegment?
        for index in points.indices.dropFirst() {
            if current?.kind != kinds[index] {
                if let segment = current { segments.append(segment) }
                current = GradeSegment(kind: kinds[index])
            }
            current?.length += points[index].distance - points[index - 1].distance
            current?.climb += points[index].altitude - points[index - 1].altitude
            current?.samples.append(points[index].sample)
        }
        if let segment = current { segments.append(segment) }
    }
    return segments
}

public func hillIndex(_ s: [FITSample]) -> Double? {
    let segments = gradeSegments(s)
    let climbs = segments.filter {
        $0.kind == .up && $0.length >= RunMetricsConstants.climbMinimumLength && $0.grade >= RunMetricsConstants.climbMinimumGrade
    }
    let flatCost = minettiCost(grade: 0)
    let climbSamples = climbs.flatMap { segment in
        segment.samples.compactMap { sample -> (speed: Double, heartRate: Int?)? in
            guard let speed = sample.speed, speed > 0 else { return nil }
            return (speed * minettiCost(grade: segment.grade) / flatCost, sample.heartRate)
        }
    }
    guard let adjusted = mean(climbSamples.map(\.speed)),
          let climbHeartRate = mean(climbSamples.compactMap { $0.heartRate.map(Double.init) })
    else { return nil }
    let flatSpeeds = segments.filter { $0.kind == .flat }.flatMap(\.samples).compactMap { sample -> Double? in
        guard let speed = sample.speed, speed > 0, let heartRate = sample.heartRate,
              abs(Double(heartRate) - climbHeartRate) <= RunMetricsConstants.flatHeartRateTolerance
        else { return nil }
        return speed
    }
    guard let flat = mean(flatSpeeds), flat > 0 else { return nil }
    return 100 * adjusted / flat
}
