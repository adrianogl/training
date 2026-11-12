import Foundation
import Metrics
import Reports
import Storage
import SwiftData
import Sync
import TrainingCore

public func raceCandidates(in context: ModelContext, today: Day) throws -> [RaceCandidate] {
    typealias C = RaceDetectionConstants
    let since = today.adding(days: -(C.lookbackDays + C.baselineDays))
    let runs = try fetchActivities(context, since: since, through: today).filter { isRun($0) && $0.fitProcessed }
    let decided = Set(try context.fetch(FetchDescriptor<RaceDecisionRecord>()).map(\.activityId))
    let linked = Set(try context.fetch(FetchDescriptor<RaceRecord>()).compactMap(\.resultActivityId))
    let unstructured = runs.filter(isUnstructured)
    let firstDay = today.adding(days: -C.lookbackDays)
    return try unstructured
        .filter { runDay($0) >= firstDay && !decided.contains($0.activityId) && !linked.contains($0.activityId) }
        .filter { try looksLikeRace($0, baseline: unstructured, context: context) }
        .sorted { $0.start > $1.start }
        .compactMap(candidate)
}

public func confirmRace(activityId: Int64, in context: ModelContext) throws {
    try record(.race, activityId: activityId, in: context)
    let alreadyLinked = try context.fetchCount(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.resultActivityId == activityId })) > 0
    if !alreadyLinked, let activity = try activity(activityId, in: context) {
        context.insert(RaceRecord(
            name: activity.name,
            day: runDay(activity).iso,
            distance: nearestNominalDistance(activity.distance ?? 0),
            goalSeconds: nil,
            priority: .c,
            resultActivityId: activityId
        ))
    }
    try context.save()
}

public func declineRace(activityId: Int64, in context: ModelContext) throws {
    try record(.notRace, activityId: activityId, in: context)
    try context.save()
}

public func autoLinkRaces(in context: ModelContext, today: Day) throws {
    let races = try context.fetch(FetchDescriptor<RaceRecord>())
    var linked = Set(races.compactMap(\.resultActivityId))
    var changed = false
    for race in races where race.resultActivityId == nil && !race.manuallyUnlinked && race.distance > 0 {
        guard let day = Day(iso: race.day), day < today else { continue }
        let match = try fetchActivities(context, since: day.adding(days: -1), through: day.adding(days: 1))
            .filter { isRun($0) && runDay($0) == day && !linked.contains($0.activityId) }
            .compactMap { run in run.distance.map { (run, abs($0 - race.distance) / race.distance) } }
            .filter { $0.1 <= RaceDetectionConstants.distanceTolerance }
            .min { $0.1 < $1.1 }?.0
        guard let match else { continue }
        race.resultActivityId = match.activityId
        race.updatedAt = .now
        linked.insert(match.activityId)
        changed = true
    }
    if changed { try context.save() }
}

private func record(_ decision: RaceDecision, activityId: Int64, in context: ModelContext) throws {
    let existing = try context.fetch(FetchDescriptor<RaceDecisionRecord>(predicate: #Predicate { $0.activityId == activityId }))
    if let first = existing.first {
        first.raceDecision = decision
        first.decidedAt = .now
    } else {
        context.insert(RaceDecisionRecord(activityId: activityId, decision: decision))
    }
}

private func activity(_ activityId: Int64, in context: ModelContext) throws -> ActivityRecord? {
    var descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == activityId })
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

private func runDay(_ activity: ActivityRecord) -> Day {
    activity.localDay.flatMap(Day.init(iso:)) ?? activityDay(activity)
}

private func isUnstructured(_ run: ActivityRecord) -> Bool {
    run.workoutName == nil && run.structureData == nil
}

private func movingPace(_ run: ActivityRecord) -> Double? {
    guard let distance = run.distance, distance > 0, let seconds = run.movingDuration ?? run.duration, seconds > 0 else { return nil }
    return seconds / distance
}

private func nearestNominalDistance(_ distance: Double) -> Double {
    RaceDetectionConstants.nominalDistances.min { abs($0 - distance) < abs($1 - distance) } ?? distance
}

private func isAtRaceDistance(_ distance: Double) -> Bool {
    let nominal = nearestNominalDistance(distance)
    return abs(distance - nominal) / nominal <= RaceDetectionConstants.distanceTolerance
}

private func looksLikeRace(_ run: ActivityRecord, baseline: [ActivityRecord], context: ModelContext) throws -> Bool {
    typealias C = RaceDetectionConstants
    guard ReportBuilder.isContinuous(run), let distance = run.distance, isAtRaceDistance(distance), let pace = movingPace(run) else { return false }
    let day = runDay(run)
    let earliest = day.adding(days: -C.baselineDays)
    let paces = baseline.compactMap { other -> Double? in
        guard other.activityId != run.activityId, other.start < run.start, runDay(other) >= earliest,
              let otherDistance = other.distance, abs(otherDistance - distance) / distance <= C.baselineDistanceTolerance
        else { return nil }
        return movingPace(other)
    }
    if let reference = median(paces) {
        return pace <= reference * (1 - C.fasterThanBaseline)
    }
    guard let averageHR = run.averageHR, let threshold = try thresholdHeartRate(on: day, in: context) else { return false }
    return averageHR >= Double(threshold) * C.thresholdFraction
}

private func candidate(_ run: ActivityRecord) -> RaceCandidate? {
    guard let distance = run.distance, let seconds = run.duration else { return nil }
    return RaceCandidate(
        activityId: run.activityId,
        day: runDay(run),
        name: run.name,
        distance: distance,
        seconds: seconds,
        averageHeartRate: run.averageHR.map { Int($0.rounded()) },
        isPR: run.pr == true
    )
}
