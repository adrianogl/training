import Foundation
import Storage
import TrainingCore

enum EvolutionExtras {
    private typealias C = EvolutionExtrasConstants

    static func zoneWeeks(_ runs: [ActivityRecord], today: Day) -> [ZoneWeek] {
        let starts = (0..<C.zoneWeeks).reversed().map { today.weekStart.adding(days: -7 * $0) }
        var totals = Dictionary(uniqueKeysWithValues: starts.map { ($0, Array(repeating: 0.0, count: C.zoneCount)) })
        for run in runs {
            let week = Day.today(now: run.start).weekStart
            guard totals[week] != nil else { continue }
            for (index, seconds) in run.zoneSeconds.prefix(C.zoneCount).enumerated() { totals[week]?[index] += seconds }
        }
        return starts.map { ZoneWeek(start: $0, seconds: totals[$0] ?? []) }
    }

    static func easyShare(_ weeks: [ZoneWeek]) -> Double? {
        let total = weeks.flatMap(\.seconds).reduce(0, +)
        guard total > 0 else { return nil }
        return weeks.flatMap { $0.seconds.prefix(C.easyZones) }.reduce(0, +) / total
    }

    static func records(_ runs: [ActivityRecord]) -> [PersonalRecord] {
        C.records.compactMap { record in
            var candidates: [PersonalRecord] = []
            let split = record.meters == 1_000 ? \ActivityRecord.fastestSplit_1000 : record.meters == 5_000 ? \ActivityRecord.fastestSplit_5000 : nil
            if let split {
                candidates += runs.compactMap { run in
                    run[keyPath: split].flatMap { $0 > 0 ? PersonalRecord(label: record.label, seconds: $0, date: run.start, source: "\(C.splitSource) \(run.workoutName ?? run.name)") : nil }
                }
            }
            candidates += runs.compactMap { run in
                guard let meters = run.distance, let seconds = run.movingDuration ?? run.duration,
                      meters >= record.meters * C.distanceTolerance.low, meters <= record.meters * C.distanceTolerance.high else { return nil }
                return PersonalRecord(label: record.label, seconds: seconds * record.meters / meters, date: run.start, source: "\(C.runSource) \(run.workoutName ?? run.name)")
            }
            return candidates.min { $0.seconds < $1.seconds }
        }
    }
}
