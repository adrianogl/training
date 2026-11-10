import FITReader
import Foundation
import Metrics
import Narrative
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

struct WorkoutAnalysisContext {
    var isRun = false
    var hasPrescription = false
    var structureMissing = false
    var zones: HeartRateZones?
    var blocks: [WorkoutBlock] = []
    var assessment = WorkoutAssessment(positives: [], negatives: [], attention: [])
    var comparison: WorkoutComparison?
    var comparisonRows: [ComparisonRow] = []
    var comparisonNotice: String?
    var evolution: EvolutionFacts?
    var score: WorkoutScore?

    nonisolated static func build(record: ActivityRecord, records: [ActivityRecord], in context: ModelContext) -> WorkoutAnalysisContext {
        build(record: record, records: records, inputs: inputs(records: records, in: context))
    }

    nonisolated static func inputs(records: [ActivityRecord], in context: ModelContext) -> WorkoutAnalysisInputs {
        WorkoutAnalysisInputs(
            zones: zones(context),
            dailyLoad: dailyLoad(records),
            readinessByDay: readinessByDay(context)
        )
    }

    static func build(record: ActivityRecord, records: [ActivityRecord], inputs: WorkoutAnalysisInputs) -> WorkoutAnalysisContext {
        var analysis = WorkoutAnalysisContext()
        analysis.isRun = ActivityTypeKey.isRun(record.typeKey)
        let structure = structure(record)
        analysis.hasPrescription = structure.map(WorkoutAnalysis.hasPrescription) ?? false
        guard analysis.isRun else { return analysis }
        analysis.structureMissing = structure == nil
        let zones = inputs.zones
        analysis.zones = zones
        let blocks = blocks(record, structure: structure, zones: zones)
        analysis.blocks = blocks

        let previous = previous(of: record, in: records)
            .prefix(WorkoutDetailConstants.maxComparisons)
            .compactMap { occurrence($0, zones: zones) }
        analysis.score = scoreWorkout(blocks: blocks, zones: zones, previous: previous)
        analysis.assessment = assess(blocks, context: AssessmentContext(
            readinessScore: record.localDay.flatMap { inputs.readinessByDay[$0] },
            acuteChronic: record.localDay.flatMap(Day.init(iso:)).flatMap { acuteChronicRatio(dailyLoad: inputs.dailyLoad, on: $0) },
            previous: previous.map(\.blocks)
        ))
        let current = WorkoutOccurrence(activityId: record.activityId, day: day(record), blocks: blocks)
        guard let comparison = compare(current: current, previous: previous) else { return analysis }
        analysis.comparison = comparison
        guard analysis.hasPrescription else {
            analysis.comparisonRows = totalRows(comparison, records: records)
            analysis.evolution = rowEvolution(analysis.comparisonRows)
            return analysis
        }
        let commonActive = commonActiveLabels(comparison, current: current)
        analysis.comparisonRows = rows(comparison, occurrences: [current] + previous, activeLabels: commonActive, records: records)
        if commonActive.isEmpty {
            analysis.evolution = rowEvolution(analysis.comparisonRows)
            analysis.comparisonNotice = comparison.sameStructure ? nil : ComparisonText.ownActiveBlocksNotice
        } else {
            analysis.evolution = deltaEvolution(comparison, rows: analysis.comparisonRows)
            analysis.comparisonNotice = comparison.sameStructure ? nil : ComparisonText.commonBlocksNotice
        }
        return analysis
    }

    static func structure(_ record: ActivityRecord) -> WorkoutStructure? {
        guard let data = record.structureData else { return nil }
        return try? JSONDecoder().decode(WorkoutStructure.self, from: data)
    }

    static func samples(_ record: ActivityRecord) -> [FITSample] {
        guard let data = record.samplesData else { return [] }
        return (try? JSONDecoder().decode([FITSample].self, from: data)) ?? []
    }

    private static func blocks(_ record: ActivityRecord, structure: WorkoutStructure?, zones: HeartRateZones?) -> [WorkoutBlock] {
        guard let structure else { return KmSplits.blocks(samples(record), zones: zones) }
        return buildBlocks(structure, zones: zones)
    }

    private static func occurrence(_ record: ActivityRecord, zones: HeartRateZones?) -> WorkoutOccurrence? {
        let blocks = blocks(record, structure: structure(record), zones: zones)
        guard !blocks.isEmpty else { return nil }
        return WorkoutOccurrence(activityId: record.activityId, day: day(record), blocks: blocks)
    }

    private static func previous(of record: ActivityRecord, in records: [ActivityRecord]) -> [ActivityRecord] {
        let earlier = records.filter { $0.activityId != record.activityId && $0.hasStart && $0.start < record.start }
        if let name = record.workoutName {
            return earlier.filter { $0.workoutName == name }
        }
        guard let distance = record.distance, distance > 0 else { return [] }
        let windowStart = record.start.addingTimeInterval(-WorkoutDetailConstants.similarRunWindowDays * WorkoutDetailConstants.secondsPerDay)
        return earlier.filter { other in
            guard ActivityTypeKey.isRun(other.typeKey), other.start >= windowStart, let otherDistance = other.distance else { return false }
            return abs(otherDistance - distance) / distance <= WorkoutDetailConstants.similarDistanceTolerance
        }
    }

    nonisolated private static func zones(_ context: ModelContext) -> HeartRateZones? {
        let records = (try? context.fetch(FetchDescriptor<HeartRateZonesRecord>())) ?? []
        guard let record = records.first(where: { $0.sport == WorkoutDetailConstants.defaultZonesSport }) ?? (records.count == 1 ? records.first : nil) else {
            return nil
        }
        return zones(from: record)
    }

    static func zones(from record: HeartRateZonesRecord) -> HeartRateZones? {
        let floors = [record.zone1Floor, record.zone2Floor, record.zone3Floor, record.zone4Floor, record.zone5Floor]
        guard floors.allSatisfy({ $0 != nil }) else { return nil }
        return HeartRateZones(floors: floors.compactMap { $0 }, maxHeartRate: record.maxHeartRate)
    }

    nonisolated private static func readinessByDay(_ context: ModelContext) -> [String: Int] {
        var descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.readinessScore != nil })
        descriptor.propertiesToFetch = [\.day, \.readinessScore]
        let records = (try? context.fetch(descriptor)) ?? []
        return records.reduce(into: [:]) { result, record in
            if let score = record.readinessScore { result[record.day] = score }
        }
    }

    private static func dailyLoad(_ records: [ActivityRecord]) -> [Day: Double] {
        var dailyLoad: [Day: Double] = [:]
        for activity in records where activity.hasStart {
            guard let activityDay = activity.localDay.flatMap(Day.init(iso:)), let load = activity.activityTrainingLoad else { continue }
            dailyLoad[activityDay, default: 0] += load
        }
        return dailyLoad
    }

    private static func day(_ record: ActivityRecord) -> Day {
        record.localDay.flatMap(Day.init(iso:)) ?? Day.today(now: record.start)
    }

    private static func commonActiveLabels(_ comparison: WorkoutComparison, current: WorkoutOccurrence) -> Set<String> {
        let common = Set(comparison.blocks.map(\.label))
        return Set(current.blocks.filter { $0.kind == .active && common.contains($0.label) }.map(\.label))
    }

    private static func rows(_ comparison: WorkoutComparison, occurrences: [WorkoutOccurrence], activeLabels: Set<String>, records: [ActivityRecord]) -> [ComparisonRow] {
        comparison.occurrences.compactMap { id in
            guard let occurrence = occurrences.first(where: { $0.activityId == id }) else { return nil }
            let active = occurrence.blocks.filter { $0.kind == .active && (activeLabels.isEmpty || activeLabels.contains($0.label)) }
            let seconds = active.reduce(0) { $0 + $1.seconds }
            let speed = seconds > 0 ? active.reduce(0) { $0 + $1.distance } / seconds : nil
            let withHeartRate = active.filter { $0.avgHeartRate != nil && $0.seconds > 0 }
            let heartRateSeconds = withHeartRate.reduce(0) { $0 + $1.seconds }
            let heartRate = heartRateSeconds > 0
                ? withHeartRate.reduce(0) { $0 + Double($1.avgHeartRate ?? 0) * $1.seconds } / heartRateSeconds
                : nil
            let targeted = active.filter { hasTarget($0) }
            let inTarget = targeted.filter { $0.status == .inTarget }.count
            let isCurrent = id == comparison.occurrences.first
            let start = records.first { $0.activityId == id }?.start
            return ComparisonRow(
                activityId: id,
                dateText: isCurrent ? ComparisonText.currentLabel : start.map(ComparisonText.shortDate) ?? "",
                isCurrent: isCurrent,
                paceText: WorkoutListModel.paceClock(metersPerSecond: speed),
                heartRateText: heartRate.map { "\(Int($0.rounded()))" },
                inTargetText: targeted.isEmpty ? nil : "\(inTarget)/\(targeted.count)",
                secondsPerKilometer: speed.map { WorkoutConstants.metersPerKilometer / $0 },
                heartRate: heartRate
            )
        }
    }

    private static func hasTarget(_ block: WorkoutBlock) -> Bool {
        guard let target = block.prescribed?.target else { return false }
        return target != .open
    }

    private static func rowEvolution(_ rows: [ComparisonRow]) -> EvolutionFacts? {
        guard rows.count > 1, let current = rows.first, let oldest = rows.last,
              let currentPace = current.secondsPerKilometer, let oldestPace = oldest.secondsPerKilometer else { return nil }
        let heartRateDelta = current.heartRate.flatMap { now in oldest.heartRate.map { now - $0 } }
        return EvolutionFacts(paceDelta: currentPace - oldestPace, heartRateDelta: heartRateDelta, oldestDate: oldest.dateText)
    }

    private static func deltaEvolution(_ comparison: WorkoutComparison, rows: [ComparisonRow]) -> EvolutionFacts? {
        guard rows.count > 1, let oldest = rows.last, let currentPace = rows.first?.secondsPerKilometer,
              let speedDelta = comparison.activeSpeedDelta else { return nil }
        let currentSpeed = WorkoutConstants.metersPerKilometer / currentPace
        let oldestSpeed = currentSpeed - speedDelta
        guard oldestSpeed > 0 else { return nil }
        let paceDelta = currentPace - WorkoutConstants.metersPerKilometer / oldestSpeed
        return EvolutionFacts(paceDelta: paceDelta, heartRateDelta: comparison.activeHeartRateDelta, oldestDate: oldest.dateText)
    }

    private static func totalRows(_ comparison: WorkoutComparison, records: [ActivityRecord]) -> [ComparisonRow] {
        comparison.occurrences.compactMap { id in
            guard let record = records.first(where: { $0.activityId == id }) else { return nil }
            let isCurrent = id == comparison.occurrences.first
            let seconds = WorkoutListModel.movingSeconds(record)
            let pace = record.distance.flatMap { distance in
                seconds.flatMap { distance > 0 ? $0 / (distance / WorkoutConstants.metersPerKilometer) : nil }
            }
            return ComparisonRow(
                activityId: id,
                dateText: isCurrent ? ComparisonText.currentLabel : ComparisonText.shortDate(record.start),
                isCurrent: isCurrent,
                paceText: pace.map(WorkoutListModel.clockText),
                heartRateText: record.averageHR.map { "\(Int($0.rounded()))" },
                inTargetText: nil,
                secondsPerKilometer: pace,
                heartRate: record.averageHR
            )
        }
    }
}
