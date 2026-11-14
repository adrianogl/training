import FITReader
import Foundation
import GarminAPI
import Insights
import Metrics
import Storage
import SwiftData
import TrainingCore

enum PlannedBriefingLoader {
    private typealias C = PlannedBriefingLoaderConstants

    static func input(
        plan: PlannedWorkout,
        week: [PlannedWorkout],
        context: ModelContext,
        today: Day,
        weeklyGoalKm: Int,
        weather: [HourlyWeather],
        course: CourseSuggestion?
    ) -> BriefingInput {
        let planDay = Day(iso: plan.day) ?? today
        let runs = ((try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? [])
            .filter { ActivityTypeKey.isRun($0.typeKey) && $0.hasStart }
        let earlier = runs.filter { ($0.localDay.flatMap(Day.init(iso:)) ?? planDay) < planDay }
        return BriefingInput(
            plan: plan,
            today: today,
            similar: similar(plan, runs: earlier),
            readiness: readiness(context: context, today: today),
            weekDoneKm: done(runs, from: planDay.weekStart, through: today),
            weekPlannedKm: projected(runs, week: week, planDay: planDay, today: today),
            weekGoalKm: weeklyGoalKm > 0 ? Double(weeklyGoalKm) : nil,
            daysSinceHard: daysSinceHard(earlier, planDay: planDay),
            race: race(context: context, today: today, runs: runs),
            weather: weather,
            course: course,
            completed: completed(runs.first { $0.localDay == plan.day })
        )
    }

    static func similar(_ plan: PlannedWorkout, runs: [ActivityRecord]) -> [SimilarRun] {
        let key = PlannedBriefingBuilder.similarityKey(plan.title)
        var matches = key.isEmpty ? [] : runs.filter { PlannedBriefingBuilder.similarityKey($0.workoutName ?? "") == key }
        if matches.isEmpty, PlannedBriefingBuilder.kind(plan) == .long, let meters = plan.estimatedMeters {
            matches = runs.filter { ($0.distance ?? 0) >= max(meters * C.longShare, C.longMinimumMeters) }
        }
        return matches.prefix(C.similarLimit).compactMap(similarRun)
    }

    private static func similarRun(_ record: ActivityRecord) -> SimilarRun? {
        guard let meters = record.distance, meters > 0, let day = record.localDay.flatMap(Day.init(iso:)) else { return nil }
        let seconds = record.movingDuration ?? record.duration ?? 0
        return SimilarRun(
            day: day,
            kilometers: meters / WorkoutConstants.metersPerKilometer,
            paceSecondsPerKm: seconds / (meters / WorkoutConstants.metersPerKilometer),
            averageHeartRate: record.averageHR,
            maxHeartRate: record.maxHR,
            aerobicEffect: record.aerobicTrainingEffect,
            load: record.activityTrainingLoad,
            fadeSecondsPerKm: fade(WorkoutAnalysisContext.samples(record))
        )
    }

    static func fade(_ samples: [FITSample]) -> Double? {
        let moving = samples.compactMap { sample -> (distance: Double, speed: Double)? in
            guard let distance = sample.distance, let speed = sample.speed, speed >= C.runningMinimumSpeed else { return nil }
            return (distance, speed)
        }
        guard let total = moving.last?.distance, total > C.fadeMinimumMeters else { return nil }
        let pace = { (from: Double, to: Double) -> Double? in
            let speeds = moving.filter { $0.distance >= from && $0.distance <= to }.map(\.speed)
            guard speeds.count >= C.fadeMinimumSamples else { return nil }
            return WorkoutConstants.metersPerKilometer / (speeds.reduce(0, +) / Double(speeds.count))
        }
        guard let middle = pace(total * C.fadeMiddleStart, total * C.fadeMiddleEnd), let last = pace(total * C.fadeMiddleEnd, total) else { return nil }
        return last - middle
    }

    private static func readiness(context: ModelContext, today: Day) -> Int? {
        let iso = today.iso
        var descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == iso })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.readinessScore
    }

    private static func done(_ runs: [ActivityRecord], from start: Day, through end: Day) -> Double {
        runs.filter { run in
            guard let day = run.localDay.flatMap(Day.init(iso:)) else { return false }
            return start <= day && day <= end
        }
        .reduce(0) { $0 + ($1.distance ?? 0) } / WorkoutConstants.metersPerKilometer
    }

    private static func projected(_ runs: [ActivityRecord], week: [PlannedWorkout], planDay: Day, today: Day) -> Double {
        let start = planDay.weekStart
        let end = start.adding(days: 6)
        let doneKm = done(runs, from: start, through: today)
        let doneDays = Set(runs.compactMap(\.localDay))
        let remaining = week.filter { plan in
            guard let day = Day(iso: plan.day) else { return false }
            return start <= day && day <= end && !doneDays.contains(plan.day) && today <= day
        }
        return doneKm + remaining.compactMap(\.estimatedMeters).reduce(0, +) / WorkoutConstants.metersPerKilometer
    }

    private static func daysSinceHard(_ runs: [ActivityRecord], planDay: Day) -> Int? {
        let hard = runs.first { run in
            (run.aerobicTrainingEffect ?? 0) >= PlannedBriefingConstants.hardAerobicEffect
                || (run.anaerobicTrainingEffect ?? 0) >= PlannedBriefingConstants.hardAnaerobicEffect
        }
        return hard?.localDay.flatMap(Day.init(iso:)).map { $0.days(until: planDay) }
    }

    private static func race(context: ModelContext, today: Day, runs: [ActivityRecord]) -> PlannedRaceContext? {
        guard let race = try? targetRace(in: context, today: today), let raceDay = Day(iso: race.day) else { return nil }
        let blockStart = raceDay.adding(days: -C.blockDays)
        let longest = runs.filter { run in (run.localDay.flatMap(Day.init(iso:)).map { $0 >= blockStart }) ?? false }
            .compactMap(\.distance).max() ?? 0
        return PlannedRaceContext(
            name: race.name,
            days: today.days(until: raceDay),
            longestKilometers: longest / WorkoutConstants.metersPerKilometer,
            longTargetKilometers: longRunTarget(raceDistance: race.distance) / WorkoutConstants.metersPerKilometer
        )
    }

    private static func completed(_ record: ActivityRecord?) -> CompletedCheck? {
        guard let record, let meters = record.distance, meters > 0 else { return nil }
        let seconds = record.movingDuration ?? record.duration
        return CompletedCheck(
            kilometers: meters / WorkoutConstants.metersPerKilometer,
            paceSecondsPerKm: seconds.map { $0 / (meters / WorkoutConstants.metersPerKilometer) },
            averageHeartRate: record.averageHR,
            fadeSecondsPerKm: fade(WorkoutAnalysisContext.samples(record))
        )
    }
}
