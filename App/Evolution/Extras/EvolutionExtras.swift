import Foundation
import Storage
import TrainingCore
import WorkoutAnalysis

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
        PersonalRecords.standings(PersonalRecords.runEfforts(runs)).map { standing in
            PersonalRecord(
                label: RecordText.label(standing.meters),
                seconds: standing.effort.seconds,
                date: standing.start,
                source: standing.effort.source == .segment ? C.splitSource : C.runSource,
                meters: standing.meters,
                activityId: standing.activityId
            )
        }
    }
}
