import FITReader
import Foundation

enum ShareTrackBuilder {
    private typealias C = ShareStudioConstants

    static func track(route: [Coordinate], samples: [FITSample]) -> [TrackPoint] {
        guard route.count >= 2 else { return [] }
        var cumulative = [0.0]
        for index in route.indices.dropFirst() {
            cumulative.append(cumulative[index - 1] + meters(route[index - 1], route[index]))
        }
        let routeTotal = cumulative.last ?? 0
        let measured = samples.filter { $0.distance != nil }
        let sampleTotal = measured.last?.distance ?? 0
        let scale = routeTotal > 0 && sampleTotal > 0 ? sampleTotal / routeTotal : 1
        return route.indices.map { index in
            let distance = cumulative[index] * scale
            let sample = nearest(measured, distance: distance)
            return TrackPoint(coordinate: route[index], distance: distance, speed: sample?.speed, heartRate: sample?.heartRate, altitude: sample?.altitude)
        }
    }

    static func trimmed(_ track: [TrackPoint], hidesEnds: Bool) -> [TrackPoint] {
        guard hidesEnds, let total = track.last?.distance, total > C.privacyMinimumDistance else { return track }
        let kept = track.filter { $0.distance >= C.privacyTrimMeters && $0.distance <= total - C.privacyTrimMeters }
        return kept.count >= 2 ? kept : track
    }

    static func thinned(_ track: [TrackPoint], limit: Int) -> [TrackPoint] {
        guard track.count > limit, limit > 1 else { return track }
        let step = Double(track.count - 1) / Double(limit - 1)
        return (0..<limit).map { track[Int((Double($0) * step).rounded())] }
    }

    static func paceLevels(_ track: [TrackPoint]) -> [Double] {
        let speeds = track.compactMap(\.speed).filter { $0 > 0 }.sorted()
        guard speeds.count >= 2 else { return track.map { _ in 0.5 } }
        let low = speeds[Int(Double(speeds.count - 1) * C.paceLowPercentile)]
        let high = speeds[Int(Double(speeds.count - 1) * C.paceHighPercentile)]
        let span = max(high - low, C.minimumSpeedSpan)
        return track.map { point in
            guard let speed = point.speed, speed > 0 else { return 0 }
            return min(max((speed - low) / span, 0), 1)
        }
    }

    static func zones(_ track: [TrackPoint], floors: [Int]) -> [Int?] {
        track.map { point in
            guard let heartRate = point.heartRate, !floors.isEmpty else { return nil }
            return (floors.lastIndex { heartRate >= $0 } ?? -1) + 1
        }
    }

    private static func nearest(_ samples: [FITSample], distance: Double) -> FITSample? {
        guard !samples.isEmpty else { return nil }
        var low = 0
        var high = samples.count - 1
        while low < high {
            let middle = (low + high) / 2
            if (samples[middle].distance ?? 0) < distance { low = middle + 1 } else { high = middle }
        }
        return samples[low]
    }

    private static func meters(_ a: Coordinate, _ b: Coordinate) -> Double {
        let radius = 6_371_000.0
        let lat1 = a.lat * .pi / 180
        let lat2 = b.lat * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.lon - a.lon) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, sqrt(h)))
    }
}
