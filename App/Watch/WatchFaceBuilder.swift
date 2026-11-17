import Foundation
import GarminAPI
import Insights
import RemoteSync
import Storage
import SwiftData
import TrainingCore

enum WatchFaceBuilder {
    private typealias C = WatchFaceConstants

    static func face(context: ModelContext, summary: TodaySummary, today: Day, planned: [PlannedWorkout], weeklyGoalKm: Int, weather: [HourlyWeather] = [], events: [WatchEvent]? = nil) -> WatchFace? {
        let race = try? targetRace(in: context, today: today)
        let goal = race == nil ? goalLine(goalSnapshots: (try? goalSnapshots(context: context, today: today)) ?? [], today: today) : nil
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
            raceName: race?.name ?? goal?.name,
            raceDay: race?.day ?? goal?.day,
            raceGoal: race?.goalSeconds.map { Int($0.rounded()) } ?? goal?.goalSeconds,
            racePrediction: race == nil ? goal?.predictionSeconds : summary.race.raceDay.map { Int($0.mid.rounded()) },
            events: events
        )
        return face == WatchFace() ? nil : face
    }

    static func goalLine(goalSnapshots: [GoalSnapshot], today: Day) -> WatchGoalLine? {
        let candidates = goalSnapshots.compactMap { snapshot -> (GoalSnapshot, Day, TimeGoalProgress)? in
            guard snapshot.kind == .time, let deadline = snapshot.deadline, deadline >= today,
                  case .time(let progress) = snapshot.progress else { return nil }
            return (snapshot, deadline, progress)
        }
        guard let (snapshot, deadline, progress) = candidates.min(by: { $0.1 < $1.1 }) else { return nil }
        return WatchGoalLine(
            name: String(String(format: C.goalNameFormat, kilometersText(snapshot.distanceKm)).prefix(C.goalNameMaxLength)),
            day: deadline.iso,
            goalSeconds: snapshot.targetSeconds.map { Int($0.rounded()) },
            predictionSeconds: progress.todaySeconds.map { Int($0.rounded()) }
        )
    }

    private static func kilometersText(_ kilometers: Double) -> String {
        let whole = kilometers.rounded()
        if abs(kilometers - whole) < C.goalWholeTolerance || kilometers >= C.goalWholeFrom { return String(Int(whole)) }
        return TodayText.decimal(kilometers, fractionDigits: 1)
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
