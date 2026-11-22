import FITReader
import Foundation
import GarminAPI
import Insights
import Metrics
import Narrative
import Storage
import SwiftData
import Sync
import TrainingCore
import WorkoutAnalysis

struct WorkoutAnalysisContext: Codable, Sendable {
    var isRun = false
    var hasPrescription = false
    var structureMissing = false
    var zones: HeartRateZones?
    var watchZones: HeartRateZones?
    var thresholdHeartRate: Int?
    var blocks: [WorkoutBlock] = []
    var kilometers: BlockKilometers = [:]
    var assessment = WorkoutAssessment(positives: [], negatives: [], attention: [])
    var comparison: WorkoutComparison?
    var comparisonRows: [ComparisonRow] = []
    var comparisonNotice: String?
    var evolution: EvolutionFacts?
    var score: WorkoutScore?
    var aboveExpected: [AboveExpectedSignal] = []

    nonisolated static func build(record: ActivityRecord, records: [ActivityRecord], in context: ModelContext) -> WorkoutAnalysisContext {
        build(record: record, records: records, inputs: inputs(records: records, in: context))
    }

    nonisolated static func inputs(records: [ActivityRecord], in context: ModelContext, races: RaceIndex? = nil) -> WorkoutAnalysisInputs {
        let runDays = records.filter { ActivityTypeKey.isRun($0.typeKey) }.map(day)
        return WorkoutAnalysisInputs(
            watchZones: (try? runningZonesRecord(in: context)).flatMap(zones(from:)),
            thresholdByDay: (try? thresholdHeartRates(on: runDays, in: context)) ?? [:],
            dailyLoad: dailyLoad(records),
            readinessByDay: readinessByDay(context),
            dailyByDay: DayConditionBuilder.dailyByDay(context),
            legDays: DayConditionBuilder.legDays(),
            hotSessions: ActivityRecord.hotSessionCounts(records),
            races: races ?? Self.races(in: context)
        )
    }

    nonisolated static func races(in context: ModelContext, paceProStore: PaceProStore = PaceProStore()) -> RaceIndex {
        var index = (try? raceIndex(in: context)) ?? RaceIndex()
        let cache = paceProStore.load()
        let withPacePro = { (target: RaceTarget) -> RaceTarget in
            guard let id = paceProStore.selectedId(race: target.id, distance: target.distance, summaries: cache.summaries),
                  let plan = cache.plans.first(where: { $0.id == id }) else { return target }
            var updated = target
            updated.strategyPaces = Dictionary(uniqueKeysWithValues: plan.kilometerSeconds.enumerated().map { ($0.offset, $0.element) })
            return updated
        }
        index.results = index.results.mapValues(withPacePro)
        index.pending = index.pending.mapValues { $0.map(withPacePro) }
        return index
    }

    static func build(record: ActivityRecord, records: [ActivityRecord], inputs: WorkoutAnalysisInputs) -> WorkoutAnalysisContext {
        var analysis = WorkoutAnalysisContext()
        analysis.isRun = ActivityTypeKey.isRun(record.typeKey)
        let structure = structure(record)
        analysis.hasPrescription = structure.map(WorkoutAnalysis.hasPrescription) ?? false
        guard analysis.isRun else { return analysis }
        analysis.structureMissing = structure == nil
        let zones = Self.zones(for: record, inputs: inputs)
        analysis.zones = zones
        analysis.watchZones = watchZones(for: record, fallback: inputs.watchZones)
        analysis.thresholdHeartRate = inputs.thresholdByDay[day(record)]
        let recordSamples = samples(record)
        let weather = record.weatherEffect(hotSessions: inputs.hotSessions)
        let blocks = blocks(record, structure: structure, zones: zones, samples: recordSamples, weather: weather)
        analysis.blocks = blocks
        if analysis.hasPrescription {
            analysis.kilometers = applyWind(kilometerSplits(of: blocks, samples: recordSamples, zones: zones), samples: recordSamples, weather: record.runWeather)
        }

        let previous = previousOccurrences(of: record, in: records, inputs: inputs)
        if let race = inputs.races.race(for: record) {
            analysis.score = scoreRace(raceInput(record, race: race), blocks: blocks, splits: kilometerSplits(recordSamples, zones: nil), previous: previous)
        } else {
            analysis.score = scoreWorkout(blocks: blocks, zones: zones, previous: previous)
        }
        analysis.assessment = assess(blocks, context: AssessmentContext(
            readinessScore: record.localDay.flatMap { inputs.readinessByDay[$0] },
            acuteChronic: record.localDay.flatMap(Day.init(iso:)).flatMap { acuteChronicRatio(dailyLoad: inputs.dailyLoad, on: $0) },
            previous: previous.map(\.blocks),
            kilometers: analysis.kilometers,
            continuity: runContinuity(recordSamples),
            weather: weather,
            samples: recordSamples,
            day: DayConditionBuilder.condition(
                record: record, records: records, daily: record.localDay.flatMap { inputs.dailyByDay[$0] }, legDays: inputs.legDays
            )
        ))
        analysis.aboveExpected = WorkoutAnalysis.aboveExpected(blocks, previous: previous.map(\.blocks))
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

    static func comparisonCandidates(of record: ActivityRecord, in records: [ActivityRecord], races: RaceIndex) -> [ActivityRecord] {
        Array(previous(of: record, in: records, races: races).prefix(WorkoutDetailConstants.maxComparisons))
    }

    static func raceInput(_ record: ActivityRecord, race: RaceTarget) -> RaceScoreInput {
        RaceScoreInput(
            raceDistance: race.distance,
            targetSeconds: race.targetSeconds,
            distance: record.distance,
            seconds: record.duration,
            referencePaces: race.strategyPaces
        )
    }

    private static func previousOccurrences(of record: ActivityRecord, in records: [ActivityRecord], inputs: WorkoutAnalysisInputs) -> [WorkoutOccurrence] {
        comparisonCandidates(of: record, in: records, races: inputs.races).compactMap { occurrence($0, zones: zones(for: $0, inputs: inputs), hotSessions: inputs.hotSessions) }
    }

    static func structure(_ record: ActivityRecord) -> WorkoutStructure? {
        guard let data = record.structureData else { return nil }
        return try? JSONDecoder().decode(WorkoutStructure.self, from: data)
    }

    static func samples(_ record: ActivityRecord) -> [FITSample] {
        SampleStore.samples(record)
    }

    private static func blocks(
        _ record: ActivityRecord, structure: WorkoutStructure?, zones: HeartRateZones?, samples: [FITSample], weather: WeatherEffect?
    ) -> [WorkoutBlock] {
        let built = structure.map { buildBlocks($0, zones: zones) } ?? kilometerSplits(samples, zones: zones)
        return adjustForWeather(applyWind(built, samples: samples, weather: record.runWeather), effect: weather)
    }

    private static func occurrence(_ record: ActivityRecord, zones: HeartRateZones?, hotSessions: [Int64: Int]) -> WorkoutOccurrence? {
        let blocks = blocks(record, structure: structure(record), zones: zones, samples: samples(record), weather: record.weatherEffect(hotSessions: hotSessions))
        guard !blocks.isEmpty else { return nil }
        return WorkoutOccurrence(activityId: record.activityId, day: day(record), blocks: blocks)
    }

    private static func previous(of record: ActivityRecord, in records: [ActivityRecord], races: RaceIndex) -> [ActivityRecord] {
        let earlier = records.filter { $0.activityId != record.activityId && $0.hasStart && $0.start < record.start }
        let isRace = races.isRace(record)
        if !isRace, let name = record.workoutName {
            let key = WorkoutTitle.comparisonKey(name)
            return earlier.filter { $0.workoutName.map(WorkoutTitle.comparisonKey) == key }
        }
        guard let distance = record.distance, distance > 0 else { return [] }
        let windowStart = record.start.addingTimeInterval(-WorkoutDetailConstants.similarRunWindowDays * WorkoutDetailConstants.secondsPerDay)
        return earlier.filter { other in
            guard ActivityTypeKey.isRun(other.typeKey), let otherDistance = other.distance,
                  abs(otherDistance - distance) / distance <= WorkoutDetailConstants.similarDistanceTolerance else { return false }
            if isRace { return races.isRace(other) }
            return other.start >= windowStart && other.workoutName == nil && !races.isRace(other)
        }
    }

    static func zones(for record: ActivityRecord, inputs: WorkoutAnalysisInputs) -> HeartRateZones? {
        guard let threshold = inputs.thresholdByDay[day(record)] else { return watchZones(for: record, fallback: inputs.watchZones) }
        var zones = thresholdZones(thresholdHeartRate: threshold)
        zones.maxHeartRate = inputs.watchZones?.maxHeartRate
        return zones
    }

    static func watchZones(for record: ActivityRecord, fallback: HeartRateZones?) -> HeartRateZones? {
        guard record.watchZoneFloors.count == WorkoutDetailConstants.zoneCount else { return fallback }
        return HeartRateZones(floors: record.watchZoneFloors, maxHeartRate: fallback?.maxHeartRate)
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

    static func day(_ record: ActivityRecord) -> Day {
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
