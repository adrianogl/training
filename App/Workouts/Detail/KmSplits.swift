import FITReader
import WorkoutAnalysis

enum KmSplits {
    static func blocks(_ samples: [FITSample], zones: HeartRateZones?) -> [WorkoutBlock] {
        let points = cumulative(samples.sorted { $0.t < $1.t })
        guard let first = points.first else { return [] }
        var blocks: [WorkoutBlock] = []
        var startTime = first.t
        var startDistance = first.distance
        var heartRates: [Int] = []
        for point in points {
            if let heartRate = point.heartRate { heartRates.append(heartRate) }
            guard point.distance - startDistance >= WorkoutDetailConstants.kmSplitDistance else { continue }
            blocks.append(block(ordinal: blocks.count + 1, start: startTime, end: point.t, distance: point.distance - startDistance, heartRates: heartRates, zones: zones))
            startTime = point.t
            startDistance = point.distance
            heartRates = []
        }
        if let last = points.last, last.distance - startDistance >= WorkoutDetailConstants.minimumPartialSplit {
            blocks.append(block(ordinal: blocks.count + 1, start: startTime, end: last.t, distance: last.distance - startDistance, heartRates: heartRates, zones: zones))
        }
        return blocks
    }

    private static func cumulative(_ samples: [FITSample]) -> [(t: Double, distance: Double, heartRate: Int?)] {
        var integrated = 0.0
        var previous: FITSample?
        return samples.map { sample in
            if let previous, let speed = previous.speed {
                integrated += speed * max(0, sample.t - previous.t)
            }
            previous = sample
            return (sample.t, sample.distance ?? integrated, sample.heartRate)
        }
    }

    private static func block(ordinal: Int, start: Double, end: Double, distance: Double, heartRates: [Int], zones: HeartRateZones?) -> WorkoutBlock {
        let seconds = max(0, end - start)
        let speed = seconds > 0 ? distance / seconds : nil
        let average = heartRates.isEmpty ? nil : Int((Double(heartRates.reduce(0, +)) / Double(heartRates.count)).rounded())
        let maximum = heartRates.max()
        let lap = LapSummary(startOffset: start, timerSeconds: seconds, distance: distance, avgSpeed: speed, avgHeartRate: average, maxHeartRate: maximum)
        return WorkoutBlock(
            kind: .active,
            ordinal: ordinal,
            label: "\(WorkoutDetailConstants.kmLabel) \(ordinal)",
            prescribed: nil,
            laps: [lap],
            seconds: seconds,
            distance: distance,
            avgSpeed: speed,
            avgHeartRate: average,
            maxHeartRate: maximum,
            dominantZone: average.flatMap { zone(of: $0, zones: zones) },
            status: .noTarget
        )
    }

    private static func zone(of heartRate: Int, zones: HeartRateZones?) -> Int? {
        guard let floors = zones?.floors else { return nil }
        let zone = floors.filter { $0 <= heartRate }.count
        return zone > 0 ? zone : nil
    }
}
