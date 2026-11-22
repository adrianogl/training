import Foundation

private typealias C = StravaRunMatchingConstants

public enum StravaRunMatching {
    public static func unmatched(_ runs: [StravaRunCandidate], existing: [(start: Date, meters: Double)]) -> [StravaRunCandidate] {
        runs.filter { run in !existing.contains { matches(run, start: $0.start, meters: $0.meters) } }
    }

    public static func matches(_ run: StravaRunCandidate, start: Date, meters: Double) -> Bool {
        abs(run.start.timeIntervalSince(start)) <= C.window
            && abs(run.distanceMeters - meters) <= max(run.distanceMeters, meters) * C.distanceTolerance
    }
}
