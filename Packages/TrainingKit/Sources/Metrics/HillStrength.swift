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

private func gradeSegments(_ s: [FITSample]) -> [GradeSegment] {
    var segments: [GradeSegment] = []
    var current: GradeSegment?
    for (previous, sample) in zip(s, s.dropFirst()) {
        guard let d0 = previous.distance, let d1 = sample.distance, d1 > d0,
              let a0 = previous.altitude, let a1 = sample.altitude
        else {
            if let segment = current { segments.append(segment) }
            current = nil
            continue
        }
        let kind = GradeClass((a1 - a0) / (d1 - d0))
        if current?.kind != kind {
            if let segment = current { segments.append(segment) }
            current = GradeSegment(kind: kind)
        }
        current?.length += d1 - d0
        current?.climb += a1 - a0
        current?.samples.append(sample)
    }
    if let segment = current { segments.append(segment) }
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
