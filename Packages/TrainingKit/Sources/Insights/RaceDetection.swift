import FITReader
import Foundation
import Metrics
import Reports
import Storage
import SwiftData
import Sync
import TrainingCore
import WorkoutAnalysis

public func raceCandidates(in context: ModelContext, today: Day) throws -> [RaceCandidate] {
    typealias C = RaceDetectionConstants
    let since = today.adding(days: -(C.lookbackDays + C.baselineDays))
    let unstructured = try fetchActivities(context, since: since, through: today).filter { isRun($0) && isUnstructured($0) }
    let decided = Set(try context.fetch(FetchDescriptor<RaceDecisionRecord>()).map(\.activityId))
    let linked = Set(try context.fetch(FetchDescriptor<RaceRecord>()).compactMap(\.resultActivityId))
    let firstDay = today.adding(days: -C.lookbackDays)
    return try unstructured
        .filter { $0.fitProcessed && runDay($0) >= firstDay && !decided.contains($0.activityId) && !linked.contains($0.activityId) }
        .filter { try looksLikeRace($0, baseline: unstructured, context: context) }
        .sorted { $0.start > $1.start }
        .compactMap(candidate)
}

public func confirmRace(activityId: Int64, in context: ModelContext) throws {
    guard let activity = try activity(activityId, in: context) else { return }
    try record(.race, activityId: activityId, in: context)
    let alreadyLinked = try context.fetchCount(FetchDescriptor<RaceRecord>(predicate: #Predicate { $0.resultActivityId == activityId })) > 0
    if !alreadyLinked {
        if let registered = try registeredRace(for: activity, in: context) {
            registered.resultActivityId = activityId
            registered.updatedAt = .now
            try context.save()
            return
        }
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
            .compactMap { run in run.distance.flatMap { distance in distanceGap(distance, race: race).map { (run, $0) } } }
            .min { $0.1 < $1.1 }?.0
        guard let match else { continue }
        race.resultActivityId = match.activityId
        race.updatedAt = .now
        linked.insert(match.activityId)
        changed = true
    }
    if changed { try context.save() }
}

private func registeredRace(for activity: ActivityRecord, in context: ModelContext) throws -> RaceRecord? {
    guard let distance = activity.distance else { return nil }
    let day = runDay(activity).iso
    let races = try context.fetch(FetchDescriptor<RaceRecord>(predicate: #Predicate {
        $0.day == day && $0.resultActivityId == nil && !$0.manuallyUnlinked
    }))
    return races
        .compactMap { race in distanceGap(distance, race: race).map { (race, $0) } }
        .min { $0.1 < $1.1 }?.0
}

private func distanceGap(_ distance: Double, race: RaceRecord) -> Double? {
    guard race.distance > 0 else { return nil }
    let gap = abs(distance - race.distance) / race.distance
    return gap <= RaceDetectionConstants.distanceTolerance ? gap : nil
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
    guard run.workoutName == nil else { return false }
    guard let structure = structure(of: run) else { return true }
    return !hasPrescription(structure)
}

private func structure(of run: ActivityRecord) -> WorkoutStructure? {
    guard let data = run.structureData else { return nil }
    return try? JSONDecoder().decode(WorkoutStructure.self, from: data)
}

private func isSteady(_ run: ActivityRecord) -> Bool {
    typealias C = RaceDetectionConstants
    let paces = (structure(of: run)?.laps ?? [])
        .filter { $0.distance >= C.fullLapMinimumDistance }
        .compactMap(lapPace)
    guard paces.count >= C.minimumFullLaps else { return ReportBuilder.isContinuous(run) }
    let mean = paces.reduce(0, +) / Double(paces.count)
    let variance = paces.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(paces.count)
    return variance.squareRoot() / mean <= C.maximumLapPaceVariation
}

private func lapPace(_ lap: LapSummary) -> Double? {
    let speed = lap.avgSpeed ?? (lap.timerSeconds > 0 ? lap.distance / lap.timerSeconds : 0)
    return speed > 0 ? 1 / speed : nil
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
    guard isSteady(run), let distance = run.distance, isAtRaceDistance(distance), let pace = movingPace(run) else { return false }
    let day = runDay(run)
    let earliest = day.adding(days: -C.baselineDays)
    let paces = baseline.compactMap { other -> Double? in
        guard other.activityId != run.activityId, other.start < run.start, runDay(other) >= earliest,
              let otherDistance = other.distance, abs(otherDistance - distance) / distance <= C.baselineDistanceTolerance
        else { return nil }
        return movingPace(other)
    }
    if paces.count >= C.minimumBaselineRuns, let reference = median(paces) {
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
