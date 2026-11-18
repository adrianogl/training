import FITReader
import Foundation
import GarminAPI
import TrainingCore

public enum HealthMapping {
    private typealias C = HealthImportConstants

    public static func activityId(_ id: UUID) -> Int64 {
        var hash = C.fnvOffset
        withUnsafeBytes(of: id.uuid) { bytes in
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* C.fnvPrime
            }
        }
        return Int64(bitPattern: (hash & C.activityIdMask) | C.activityIdMarker)
    }

    public static func localString(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d-%02d-%02d %02d:%02d:%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }

    public static func typeKey(_ kind: HealthWorkoutKind, indoor: Bool) -> String {
        switch kind {
        case .run: indoor ? "treadmill_running" : "running"
        case .walk: "walking"
        case .strength: "strength_training"
        case .other: "other"
        }
    }

    public static func trimp(durationSeconds: Double, averageHeartRate: Double?, resting: Double, maximum: Double) -> Double? {
        guard let averageHeartRate, maximum > resting, durationSeconds > 0 else { return nil }
        let reserve = min(max((averageHeartRate - resting) / (maximum - resting), 0), 1)
        return (durationSeconds / 60 * reserve * C.trimpFactor * exp(C.trimpExponent * reserve)).rounded()
    }

    public static func activity(_ workout: HealthWorkout, resting: Double, maximum: Double) -> ActivityDTO {
        ActivityDTO(
            activityId: activityId(workout.id),
            typeKey: typeKey(workout.kind, indoor: workout.indoor),
            startTimeLocal: localString(workout.start),
            distance: workout.distanceMeters,
            duration: workout.duration,
            movingDuration: workout.duration,
            averageHR: workout.averageHeartRate,
            maxHR: workout.maxHeartRate,
            activityTrainingLoad: trimp(durationSeconds: workout.duration, averageHeartRate: workout.averageHeartRate, resting: resting, maximum: maximum),
            averageRunningCadenceInStepsPerMinute: workout.averageCadence,
            avgGroundContactTime: workout.averageGroundContactMs,
            avgVerticalOscillation: workout.averageVerticalOscillationCm,
            avgStrideLength: workout.averageStrideMeters.map { $0 * 100 },
            avgPower: workout.averagePower,
            elevationGain: workout.elevationGain
        )
    }

    public static func hrvBaseline(_ history: [Double]) -> (lowUpper: Double, balancedLow: Double, balancedUpper: Double)? {
        guard history.count >= C.hrvMinimumNights else { return nil }
        let mean = history.reduce(0, +) / Double(history.count)
        let variance = history.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(history.count)
        let sd = max(variance.squareRoot(), mean * 0.05)
        return (mean - C.hrvLowSD * sd, mean - C.hrvBalancedLowSD * sd, mean + C.hrvBalancedHighSD * sd)
    }

    public static func hrvStatus(_ value: Double, baseline: (lowUpper: Double, balancedLow: Double, balancedUpper: Double)) -> String {
        if value < baseline.lowUpper { return "LOW" }
        if value < baseline.balancedLow || value > baseline.balancedUpper { return "UNBALANCED" }
        return "BALANCED"
    }

    public static func sleepScore(_ night: HealthSleepNight) -> Int? {
        guard night.asleepSeconds > 0 else { return nil }
        let duration = min(night.asleepSeconds / C.sleepTargetSeconds, 1) * C.sleepDurationPoints
        let stages = min((night.deepSeconds + night.remSeconds) / night.asleepSeconds / C.sleepStageTarget, 1) * C.sleepStagePoints
        return Int((duration + stages).rounded())
    }

    public static func sleep(_ night: HealthSleepNight, timeZone: TimeZone = .current) -> SleepDTO {
        let gmt = Int64(night.end.timeIntervalSince1970 * C.millisecondsPerSecond)
        let local = gmt + Int64(timeZone.secondsFromGMT(for: night.end)) * Int64(C.millisecondsPerSecond)
        return SleepDTO(
            day: night.day,
            sleepTimeSeconds: Int(night.asleepSeconds),
            deepSleepSeconds: Int(night.deepSeconds),
            lightSleepSeconds: Int(night.coreSeconds),
            remSleepSeconds: Int(night.remSeconds),
            awakeSleepSeconds: Int(night.awakeSeconds),
            overallScore: sleepScore(night),
            sleepEndTimestampLocal: local,
            sleepEndTimestampGMT: gmt
        )
    }

    public static func zones(maximum: Double, resting: Double) -> HRZonesDTO {
        let floors = C.zoneFloors.map { Int(($0 * maximum).rounded()) }
        return HRZonesDTO(
            sport: C.defaultZonesSport, zone1Floor: floors[0], zone2Floor: floors[1], zone3Floor: floors[2], zone4Floor: floors[3],
            zone5Floor: floors[4], maxHeartRateUsed: Int(maximum.rounded()), restingHeartRateUsed: Int(resting.rounded())
        )
    }

    public static func summary(_ workout: HealthWorkout, series: HealthSeries) -> FITSummary {
        let duration = max(workout.end.timeIntervalSince(workout.start), workout.duration)
        let cumulative = cumulativeDistance(series.distance, start: workout.start)
        var samples: [FITSample] = []
        var t = 0.0
        while t <= duration {
            let at = workout.start.addingTimeInterval(t)
            let route = nearest(series.route, to: at)
            let distance = interpolate(cumulative, at: t)
            samples.append(FITSample(
                t: t,
                heartRate: latest(series.heartRate, at: at).map { Int($0.rounded()) },
                speed: latest(series.speed, at: at) ?? derivedSpeed(cumulative, at: t),
                altitude: route?.altitude,
                distance: distance,
                cadence: latest(series.cadence, at: at),
                stanceTime: latest(series.groundContactMs, at: at),
                lat: route?.latitude,
                lon: route?.longitude
            ))
            t += C.sampleStep
        }
        let laps = series.laps.map { lap -> LapSummary in
            let from = lap.start.timeIntervalSince(workout.start)
            let to = lap.end.timeIntervalSince(workout.start)
            let meters = max((interpolate(cumulative, at: to) ?? 0) - (interpolate(cumulative, at: from) ?? 0), 0)
            let hr = series.heartRate.filter { $0.date >= lap.start && $0.date <= lap.end }.map(\.value)
            return LapSummary(
                startOffset: from, timerSeconds: to - from, distance: meters,
                avgSpeed: to > from ? meters / (to - from) : nil,
                avgHeartRate: hr.isEmpty ? nil : Int((hr.reduce(0, +) / Double(hr.count)).rounded()),
                maxHeartRate: hr.max().map { Int($0.rounded()) }
            )
        }
        return FITSummary(
            samples: samples,
            route: series.route.map { Coordinate(lat: $0.latitude, lon: $0.longitude) },
            physio: workout.vo2max.map { PhysioMetrics(vo2max: $0) },
            structure: WorkoutStructure(laps: laps),
            zoneInfo: nil
        )
    }

    static func cumulativeDistance(_ increments: [HealthPoint], start: Date) -> [(t: Double, meters: Double)] {
        var total = 0.0
        var points: [(t: Double, meters: Double)] = [(0, 0)]
        for point in increments.sorted(by: { $0.date < $1.date }) {
            total += point.value
            points.append((point.date.timeIntervalSince(start), total))
        }
        return points.count > 1 ? points : []
    }

    static func interpolate(_ points: [(t: Double, meters: Double)], at t: Double) -> Double? {
        guard let first = points.first, let last = points.last else { return nil }
        if t <= first.t { return first.meters }
        if t >= last.t { return last.meters }
        guard let index = points.firstIndex(where: { $0.t >= t }), index > 0 else { return last.meters }
        let a = points[index - 1], b = points[index]
        guard b.t > a.t else { return b.meters }
        return a.meters + (b.meters - a.meters) * (t - a.t) / (b.t - a.t)
    }

    static func derivedSpeed(_ points: [(t: Double, meters: Double)], at t: Double) -> Double? {
        let half = C.speedWindow / 2
        guard let ahead = interpolate(points, at: t + half), let behind = interpolate(points, at: max(t - half, 0)) else { return nil }
        let span = (t + half) - max(t - half, 0)
        return span > 0 ? max(ahead - behind, 0) / span : nil
    }

    static func latest(_ points: [HealthPoint], at date: Date) -> Double? {
        guard let first = points.first, date >= first.date.addingTimeInterval(-C.speedWindow) else { return nil }
        return points.last { $0.date <= date }?.value ?? first.value
    }

    static func nearest(_ route: [HealthRoutePoint], to date: Date) -> HealthRoutePoint? {
        guard !route.isEmpty else { return nil }
        var low = 0, high = route.count - 1
        while low < high {
            let mid = (low + high) / 2
            if route[mid].date < date { low = mid + 1 } else { high = mid }
        }
        if low > 0, abs(route[low - 1].date.timeIntervalSince(date)) < abs(route[low].date.timeIntervalSince(date)) { return route[low - 1] }
        return route[low]
    }
}
