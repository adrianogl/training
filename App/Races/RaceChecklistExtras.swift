import FITReader
import Foundation
import Metrics
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

enum RaceChecklistExtras {
    private typealias C = RacesConstants

    struct Input {
        let today: Day
        let blockStart: Day
        let distance: Double
        let goalSeconds: Double?
        let priority: RacePriority
        let profile: [GPXPoint]?
        let targetPace: Double?
        let weeklyKm: [Day: Double]
        let runs: [ActivityRecord]
    }

    static func items(_ input: Input) -> [ChecklistItem] {
        [
            weeklyVolume(input),
            racePace(input),
            tuneUp(input),
            course(input),
            goal(input),
        ]
    }

    static func weeklyVolumeTarget(distance: Double) -> Double {
        C.weeklyVolumeTargets.first { distance <= $0.upTo }?.km ?? C.weeklyVolumeTargets.last?.km ?? 0
    }

    static func racePaceTarget(distance: Double) -> Double {
        (distance / C.metersPerKm * C.racePaceVolumeRatio).rounded()
    }

    static func tuneUpDistance(distance: Double) -> Double {
        (distance / C.metersPerKm / 2).rounded(.down)
    }

    static func recentAverage(weeklyKm: [Day: Double], today: Day) -> Double? {
        let currentWeek = today.weekStart
        let known = (1...C.recentWeeks).compactMap { weeklyKm[currentWeek.adding(days: -C.daysPerWeek * $0)] }
        guard !known.isEmpty else { return nil }
        return known.reduce(0, +) / Double(C.recentWeeks)
    }

    static func racePaceKm(splits: [[RaceSplit]], targetPace: Double) -> Double {
        splits.joined()
            .filter { $0.distance >= C.metersPerKm * C.fullSplitRatio }
            .filter { $0.pace >= targetPace - C.racePaceFaster && $0.pace <= targetPace + C.racePaceSlower }
            .reduce(0) { $0 + $1.distance } / C.metersPerKm
    }

    private static func weeklyVolume(_ input: Input) -> ChecklistItem {
        let target = weeklyVolumeTarget(distance: input.distance)
        let title = String(format: C.weeklyVolumeTitle, RacesText.km(target))
        guard let average = recentAverage(weeklyKm: input.weeklyKm, today: input.today) else {
            return ChecklistItem(kind: .weeklyVolume, title: title, detail: C.weeklyVolumeMissing, status: .missing)
        }
        return ChecklistItem(
            kind: .weeklyVolume,
            title: title,
            detail: String(format: C.weeklyVolumeDetail, RacesText.km(average)),
            status: average >= target ? .ok : .attention
        )
    }

    private static func racePace(_ input: Input) -> ChecklistItem {
        let target = racePaceTarget(distance: input.distance)
        guard let pace = input.targetPace else {
            return ChecklistItem(kind: .racePace, title: C.racePaceTitle, detail: C.racePaceMissing, status: .missing)
        }
        let splits = input.runs.filter { Day.today(now: $0.start) >= input.blockStart }.map(splits)
        let done = racePaceKm(splits: splits, targetPace: pace)
        return ChecklistItem(
            kind: .racePace,
            title: C.racePaceTitle,
            detail: String(format: C.racePaceDetail, RacesText.km(done), RacesText.paceText(pace), RacesText.km(target)),
            status: done >= target ? .ok : .attention
        )
    }

    private static func tuneUp(_ input: Input) -> ChecklistItem {
        let distance = tuneUpDistance(distance: input.distance)
        let title = String(format: C.tuneUpTitle, RacesText.km(distance))
        let candidates = input.runs.filter { run in
            guard Day.today(now: run.start) >= input.blockStart, let meters = run.distance, meters >= distance * C.metersPerKm * C.tuneUpDistanceRatio,
                  let seconds = run.movingDuration ?? run.duration, let pace = input.targetPace else { return false }
            return seconds / (meters / C.metersPerKm) <= pace + C.tuneUpPaceMargin
        }
        guard let best = candidates.max(by: { $0.start < $1.start }), let meters = best.distance,
              let seconds = best.movingDuration ?? best.duration else {
            return ChecklistItem(kind: .tuneUp, title: title, detail: String(format: C.tuneUpMissing, RacesText.km(distance)), status: .missing)
        }
        let detail = String(
            format: C.tuneUpDetail,
            ComparisonText.shortDate(best.start), RacesText.km(meters / C.metersPerKm),
            RacesText.paceText(seconds / (meters / C.metersPerKm))
        )
        return ChecklistItem(kind: .tuneUp, title: title, detail: detail, status: .ok)
    }

    private static func course(_ input: Input) -> ChecklistItem {
        guard let profile = input.profile, profile.count > 1, let last = profile.last else {
            return ChecklistItem(kind: .course, title: C.courseChecklistTitle, detail: C.courseMissing, status: .missing)
        }
        let gain = zip(profile, profile.dropFirst()).reduce(0) { $0 + max(0, $1.1.altitude - $1.0.altitude) }
        return ChecklistItem(
            kind: .course,
            title: C.courseChecklistTitle,
            detail: String(format: C.courseDetail, RacesText.km(last.distance / C.metersPerKm), Int(gain.rounded())),
            status: .ok
        )
    }

    private static func goal(_ input: Input) -> ChecklistItem {
        guard let goal = input.goalSeconds else {
            return ChecklistItem(kind: .goal, title: C.goalTitle, detail: C.goalMissing, status: .missing)
        }
        return ChecklistItem(
            kind: .goal,
            title: C.goalTitle,
            detail: String(format: C.goalDetail, WorkoutFormat.clock(goal), input.priority.rawValue),
            status: .ok
        )
    }

    private static func splits(_ run: ActivityRecord) -> [RaceSplit] {
        guard let data = run.samplesData, let samples = try? JSONDecoder().decode([FITSample].self, from: data) else { return [] }
        return kilometerSplits(samples, zones: nil).enumerated().compactMap { index, block in
            guard block.distance > 0 else { return nil }
            return RaceSplit(index: index, distance: block.distance, pace: block.seconds / (block.distance / C.metersPerKm), planned: nil)
        }
    }
}
