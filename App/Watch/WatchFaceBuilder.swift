import Foundation
import GarminAPI
import Insights
import RemoteSync
import Storage
import SwiftData
import TrainingCore

enum WatchFaceBuilder {
    private typealias C = WatchFaceConstants

    static func face(context: ModelContext, summary: TodaySummary, today: Day, planned: [PlannedWorkout], weeklyGoalKm: Int, weather: [HourlyWeather] = []) -> WatchFace? {
        let race = try? targetRace(in: context, today: today)
        let todayPlan = planned.first { $0.day == today.iso }
        let face = WatchFace(
            vo2Delta: vo2Delta(context: context, today: today),
            weekPlannedKm: weekPlannedKm(planned, today: today),
            weekGoalKm: weeklyGoalKm > 0 ? Double(weeklyGoalKm) : nil,
            workout: todayPlan?.title,
            workoutShape: todayPlan.flatMap { shape($0.steps) },
            workoutTip: todayPlan.flatMap { plan in
                PlannedBriefingBuilder.briefing(PlannedBriefingLoader.input(
                    plan: plan, week: planned, context: context, today: today,
                    weeklyGoalKm: weeklyGoalKm, weather: weather, course: nil
                )).watchTip
            },
            raceName: race?.name,
            raceDay: race?.day,
            raceGoal: race?.goalSeconds.map { Int($0.rounded()) },
            racePrediction: race == nil ? nil : summary.race.raceDay.map { Int($0.mid.rounded()) }
        )
        return face == WatchFace() ? nil : face
    }

    static func vo2Delta(context: ModelContext, today: Day) -> Double? {
        let start = today.adding(days: -C.vo2WindowDays)
        let points = ((try? metricSeries(.vo2max, context: context, today: today, period: .sixMonths))?.points ?? [])
            .filter { $0.0 >= start }
        guard let first = points.first?.1, let last = points.last?.1, points.count >= 2 else { return nil }
        return ((last - first) * C.vo2Precision).rounded() / C.vo2Precision
    }

    static func weekPlannedKm(_ planned: [PlannedWorkout], today: Day) -> Double? {
        let start = today.weekStart
        let days = Set((0..<C.daysPerWeek).map { start.adding(days: $0).iso })
        let meters = planned.filter { days.contains($0.day) }.compactMap(\.estimatedMeters)
        guard !meters.isEmpty else { return nil }
        return (meters.reduce(0, +) / C.metersPerKm * C.weekKmPrecision).rounded() / C.weekKmPrecision
    }

    static func shape(_ steps: [PlannedStep]) -> [[Int]]? {
        var parts = steps.flatMap(\.flattened).map { (weight: PlanText.weight($0), zone: PlanText.level($0)) }
        while parts.count > C.shapeMaxSteps {
            parts = stride(from: 0, to: parts.count, by: 2).map { index in
                guard index + 1 < parts.count else { return parts[index] }
                let pair = (parts[index], parts[index + 1])
                return (weight: pair.0.weight + pair.1.weight, zone: max(pair.0.zone, pair.1.zone))
            }
        }
        let total = parts.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        return parts.map { [max(1, Int(($0.weight / total * C.shapeWeightScale).rounded())), $0.zone] }
    }
}
