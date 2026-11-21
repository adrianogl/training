import FITReader
import Foundation
import Storage

public enum PersonalRecords {
    private typealias C = PersonalRecordsConstants

    public static func efforts(record: ActivityRecord, samples: [FITSample]) -> [RunEffort] {
        let points = samples.compactMap { sample in sample.distance.map { (t: sample.t, d: $0) } }
        var best: [Double: RunEffort] = [:]
        func offer(_ effort: RunEffort) {
            if let current = best[effort.meters], current.seconds <= effort.seconds { return }
            best[effort.meters] = effort
        }
        if let distance = record.distance, let seconds = record.movingDuration ?? record.duration, distance > 0, seconds > 0 {
            for meters in C.distances where distance >= meters * C.wholeRunLow && distance <= meters * C.wholeRunHigh {
                offer(RunEffort(meters: meters, seconds: seconds * meters / distance, source: .wholeRun))
            }
        }
        for meters in C.segmentDistances {
            if let segment = bestSegment(points, meters: meters) {
                offer(RunEffort(meters: meters, seconds: segment.seconds, source: .segment, startMeters: segment.startMeters))
            } else if let split = garminSplit(record, meters: meters) {
                offer(RunEffort(meters: meters, seconds: split, source: .segment))
            }
        }
        return C.distances.compactMap { best[$0] }
    }

    static func garminSplit(_ record: ActivityRecord, meters: Double) -> Double? {
        let value = meters == 1_000 ? record.fastestSplit_1000 : meters == 5_000 ? record.fastestSplit_5000 : nil
        return value.flatMap { $0 > 0 ? $0 : nil }
    }

    public static func bestSegment(_ points: [(t: Double, d: Double)], meters: Double) -> (seconds: Double, startMeters: Double)? {
        guard let last = points.last, let first = points.first, last.d - first.d >= meters else { return nil }
        var best: (seconds: Double, startMeters: Double)?
        var start = 0
        for end in points.indices {
            let target = points[end].d - meters
            guard target >= points[0].d else { continue }
            while start + 1 < end, points[start + 1].d <= target { start += 1 }
            let a = points[start]
            let b = points[start + 1]
            guard b.t - a.t <= C.segmentMaximumGap || a.d == target else { continue }
            let span = b.d - a.d
            let startTime = span > 0 ? a.t + (target - a.d) / span * (b.t - a.t) : a.t
            let seconds = points[end].t - startTime
            guard seconds > 0 else { continue }
            if best == nil || seconds < best!.seconds { best = (seconds, target) }
        }
        return best
    }

    public static func timeline(_ runs: [RunEfforts]) -> [Int64: RunRecords] {
        var bests: [Double: Double] = [:]
        var bestStarts: [Double: Date] = [:]
        var result: [Int64: RunRecords] = [:]
        for run in runs.sorted(by: { $0.start < $1.start }) {
            var hits: [RecordHit] = []
            var near: RecordNear?
            for effort in run.efforts {
                if let best = bests[effort.meters] {
                    if effort.seconds < best {
                        hits.append(RecordHit(effort: effort, previousSeconds: best, previousStart: bestStarts[effort.meters]))
                    } else if effort.seconds <= best * C.nearShare, near == nil || effort.meters > near!.effort.meters {
                        near = RecordNear(effort: effort, bestSeconds: best)
                    }
                } else if !bests.isEmpty {
                    hits.append(RecordHit(effort: effort, previousSeconds: nil))
                }
                if effort.seconds < bests[effort.meters] ?? .infinity {
                    bests[effort.meters] = effort.seconds
                    bestStarts[effort.meters] = run.start
                }
            }
            hits.sort { $0.effort.meters > $1.effort.meters }
            if !hits.isEmpty || near != nil { result[run.activityId] = RunRecords(records: hits, near: hits.isEmpty ? near : nil) }
        }
        return result
    }

    public static func progression(_ runs: [RunEfforts], meters: Double, through activityId: Int64) -> [RecordStep] {
        var steps: [RecordStep] = []
        for run in runs.sorted(by: { $0.start < $1.start }) {
            if let effort = run.efforts.first(where: { $0.meters == meters }), effort.seconds < steps.last?.seconds ?? .infinity {
                steps.append(RecordStep(activityId: run.activityId, start: run.start, seconds: effort.seconds))
            }
            if run.activityId == activityId { break }
        }
        return steps
    }

    public static func standings(_ runs: [RunEfforts]) -> [RecordStanding] {
        C.distances.compactMap { meters in
            runs.compactMap { run in run.efforts.first { $0.meters == meters }.map { (run, $0) } }
                .min { $0.1.seconds < $1.1.seconds }
                .map { RecordStanding(meters: meters, activityId: $0.0.activityId, start: $0.0.start, effort: $0.1) }
        }
    }
}
