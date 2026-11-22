import FITReader
import Foundation
import GarminAPI
import RemoteSync
import TrainingCore

public enum StravaRunMapping {
    private typealias C = StravaRunMappingConstants

    public static func typeKey(_ run: StravaRunCandidate) -> String {
        if run.sportType == C.virtualSport || !run.hasGps { return C.treadmill }
        return run.sportType == C.trailSport ? C.trail : C.running
    }

    public static func localString(_ startLocal: String) -> String {
        String(startLocal.replacingOccurrences(of: "T", with: " ").prefix(19))
    }

    public static func activity(_ run: StravaRunCandidate, resting: Double?, maximum: Double?) -> ActivityDTO {
        ActivityDTO(
            activityId: StravaActivityId.make(run.id),
            activityName: run.name,
            typeKey: typeKey(run),
            startTimeLocal: localString(run.startLocal),
            distance: run.distanceMeters,
            duration: run.elapsedSeconds,
            movingDuration: run.movingSeconds,
            averageHR: run.averageHeartRate,
            maxHR: run.maxHeartRate,
            activityTrainingLoad: HealthMapping.trimp(
                durationSeconds: run.movingSeconds, averageHeartRate: run.averageHeartRate,
                resting: resting ?? C.fallbackRestingHeartRate, maximum: maximum ?? C.fallbackMaxHeartRate
            ),
            elevationGain: run.elevationGain
        )
    }

    public static func summary(_ streams: StravaStreams) -> FITSummary {
        let time = streams.time
        var samples: [FITSample] = []
        if let last = time.last {
            var index = 0
            var t = 0.0
            while t <= last {
                while index + 1 < time.count, time[index + 1] <= t { index += 1 }
                let point = streams.latlng[safe: index]
                samples.append(FITSample(
                    t: t,
                    heartRate: streams.heartrate[safe: index].map { Int($0.rounded()) },
                    speed: streams.velocity[safe: index],
                    altitude: streams.altitude[safe: index],
                    distance: streams.distance[safe: index],
                    cadence: streams.cadence[safe: index].map { $0 * C.stepsPerStride },
                    lat: point.flatMap { $0.count == 2 ? $0[0] : nil },
                    lon: point.flatMap { $0.count == 2 ? $0[1] : nil }
                ))
                t += C.sampleStep
            }
        }
        return FITSummary(
            samples: samples,
            route: streams.latlng.filter { $0.count == 2 }.map { Coordinate(lat: $0[0], lon: $0[1]) },
            physio: nil,
            structure: WorkoutStructure(laps: []),
            zoneInfo: nil
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
