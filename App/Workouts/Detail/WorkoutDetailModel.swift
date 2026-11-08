import FITReader
import Foundation
import Metrics
import Observation
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

@MainActor @Observable final class WorkoutDetailModel {
    let activityId: Int64
    private(set) var summary: WorkoutSummary?
    private(set) var isRun = false
    private(set) var hasPrescription = false
    private(set) var structureMissing = false
    private(set) var blocks: [WorkoutBlock] = []
    private(set) var bars: [BlockBar] = []
    private(set) var assessment = WorkoutAssessment(positives: [], negatives: [], attention: [])
    private(set) var comparison: WorkoutComparison?
    private(set) var comparisonRows: [ComparisonRow] = []
    private(set) var comparisonTitle = ""
    private(set) var comparisonNotice: String?
    private(set) var evolutionText: String?
    private(set) var route: [Coordinate] = []
    private(set) var heartRate: [(t: Double, bpm: Int)] = []
    private(set) var altitude: [(t: Double, meters: Double)] = []
    private(set) var zoneBands: [ZoneBand] = []
    private(set) var activeSpans: [BlockSpan] = []
    private(set) var zoneShares: [ZoneShare] = []
    private(set) var shareInput: WorkoutShareInput?

    init(activityId: Int64, context: ModelContext) {
        self.activityId = activityId
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        guard let record = records.first(where: { $0.activityId == activityId }) else { return }
        isRun = ActivityTypeKey.isRun(record.typeKey)
        let structure = Self.structure(record)
        hasPrescription = structure.map(WorkoutAnalysis.hasPrescription) ?? false
        summary = Self.summary(record, isRun: isRun, hasPrescription: hasPrescription)
        zoneShares = Self.zoneShares(record.zoneSeconds)
        guard isRun else { return }
        structureMissing = structure == nil
        let zones = Self.zones(context)
        blocks = Self.blocks(record, structure: structure, zones: zones)
        bars = BlockBarScale.bars(blocks, zones: zones)
        let samples = Self.samples(record)
        route = ChartData.routePoints(Self.route(record))
        let fullHeartRate = ChartData.heartRateSeries(samples)
        heartRate = ChartData.thinned(fullHeartRate, limit: WorkoutDetailConstants.maxChartPoints) { Double($0.bpm) }
        altitude = ChartData.thinned(ChartData.altitudeSeries(samples), limit: WorkoutDetailConstants.maxChartPoints) { $0.meters }
        zoneBands = ChartData.zoneBands(zones, ceiling: Double(fullHeartRate.map { $0.bpm }.max() ?? 0))
        activeSpans = hasPrescription ? ChartData.activeSpans(blocks) : []

        let previous = Self.previous(of: record, in: records)
            .prefix(WorkoutDetailConstants.maxComparisons)
            .compactMap { Self.occurrence($0, zones: zones) }
        assessment = assess(blocks, context: AssessmentContext(
            readinessScore: Self.readiness(record, context: context),
            acuteChronic: Self.acuteChronic(record, records: records),
            previous: previous.map(\.blocks)
        ))
        let current = WorkoutOccurrence(activityId: record.activityId, day: Self.day(record), blocks: blocks)
        comparison = compare(current: current, previous: previous)
        shareInput = Self.shareInput(record, blocks: blocks, route: route, hasPrescription: hasPrescription, assessment: assessment)
        comparisonTitle = record.workoutName ?? WorkoutDetailConstants.similarRunsTitle
        guard let comparison else { return }
        guard hasPrescription else {
            comparisonRows = Self.totalRows(comparison, records: records)
            evolutionText = Self.rowEvolution(comparisonRows)
            return
        }
        let commonActive = Self.commonActiveLabels(comparison, current: current)
        comparisonRows = Self.rows(comparison, occurrences: [current] + previous, activeLabels: commonActive, records: records)
        if commonActive.isEmpty {
            evolutionText = Self.rowEvolution(comparisonRows)
            comparisonNotice = comparison.sameStructure ? nil : ComparisonText.ownActiveBlocksNotice
        } else {
            evolutionText = Self.deltaEvolution(comparison, rows: comparisonRows)
            comparisonNotice = comparison.sameStructure ? nil : ComparisonText.commonBlocksNotice
        }
    }


    private static func shareInput(
        _ record: ActivityRecord,
        blocks: [WorkoutBlock],
        route: [Coordinate],
        hasPrescription: Bool,
        assessment: WorkoutAssessment
    ) -> WorkoutShareInput {
        let distance = record.distance.flatMap { $0 > 0 ? $0 : nil }
        let seconds = WorkoutListModel.movingSeconds(record)
        let pace = distance.flatMap { meters in seconds.map { $0 / (meters / WorkoutConstants.metersPerKilometer) } }
        let active = blocks.filter { $0.kind == .active }
        let activeSeconds = active.reduce(0) { $0 + $1.seconds }
        let activeDistance = active.reduce(0) { $0 + $1.distance }
        let activePace = hasPrescription && activeDistance > 0 ? activeSeconds / (activeDistance / WorkoutConstants.metersPerKilometer) : nil
        return WorkoutShareInput(
            title: record.workoutName ?? record.name,
            dateText: ComparisonText.shortDate(record.start),
            distanceMeters: distance,
            movingSeconds: seconds,
            avgPaceSecondsPerKm: pace,
            avgHeartRate: record.averageHR,
            activePaceSecondsPerKm: activePace,
            elevationGain: record.elevationGain,
            route: route,
            blocks: blocks,
            readingLine: assessment.positives.first.map { FindingTemplates.text($0, blocks: blocks) }
        )
    }

    private static func structure(_ record: ActivityRecord) -> WorkoutStructure? {
        guard let data = record.structureData else { return nil }
        return try? JSONDecoder().decode(WorkoutStructure.self, from: data)
    }

    private static func route(_ record: ActivityRecord) -> [Coordinate] {
        guard let data = record.routeData else { return [] }
        return (try? JSONDecoder().decode([Coordinate].self, from: data)) ?? []
    }

    private static func zoneShares(_ seconds: [Double]) -> [ZoneShare] {
        let shares = ChartData.zoneShares(seconds)
        guard shares.contains(where: { $0 > 0 }) else { return [] }
        return zip(shares, seconds).enumerated().map { index, pair in
            ZoneShare(zone: index + 1, share: pair.0, seconds: pair.1)
        }
    }

    private static func samples(_ record: ActivityRecord) -> [FITSample] {
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

    private static func zones(_ context: ModelContext) -> HeartRateZones? {
        let records = (try? context.fetch(FetchDescriptor<HeartRateZonesRecord>())) ?? []
        guard let record = records.first(where: { $0.sport == WorkoutDetailConstants.defaultZonesSport }) ?? (records.count == 1 ? records.first : nil) else {
            return nil
        }
        let floors = [record.zone1Floor, record.zone2Floor, record.zone3Floor, record.zone4Floor, record.zone5Floor].compactMap { $0 }
        guard !floors.isEmpty else { return nil }
        return HeartRateZones(floors: floors, maxHeartRate: record.maxHeartRate)
    }

    private static func readiness(_ record: ActivityRecord, context: ModelContext) -> Int? {
        guard let localDay = record.localDay else { return nil }
        var descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == localDay })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.readinessScore
    }

    private static func acuteChronic(_ record: ActivityRecord, records: [ActivityRecord]) -> Double? {
        guard let day = record.localDay.flatMap(Day.init(iso:)) else { return nil }
        var dailyLoad: [Day: Double] = [:]
        for activity in records where activity.hasStart {
            guard let activityDay = activity.localDay.flatMap(Day.init(iso:)), let load = activity.activityTrainingLoad else { continue }
            dailyLoad[activityDay, default: 0] += load
        }
        return acuteChronicRatio(dailyLoad: dailyLoad, on: day)
    }

    private static func day(_ record: ActivityRecord) -> Day {
        record.localDay.flatMap(Day.init(iso:)) ?? Day.today(now: record.start)
    }

    private static func summary(_ record: ActivityRecord, isRun: Bool, hasPrescription: Bool) -> WorkoutSummary {
        let row = WorkoutListModel.row(record)
        let kind = hasPrescription ? "Treino do Treinus" : isRun ? "Corrida livre" : record.name
        let subtitle = [kind == row.title ? nil : kind, record.locationName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return WorkoutSummary(
            title: row.title,
            dateText: row.dateText,
            subtitle: subtitle,
            distanceText: record.distance.flatMap { $0 > 0 ? $0 : nil }.map(WorkoutFormat.kilometers),
            durationText: row.durationText,
            paceText: row.paceText,
            averageHeartRateText: record.averageHR.map { "\(Int($0.rounded()))" },
            maxHeartRateText: record.maxHR.map { "\(Int($0.rounded()))" },
            loadText: record.activityTrainingLoad.map { "\(Int($0.rounded()))" },
            hasPrescription: hasPrescription
        )
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

    private static func rowEvolution(_ rows: [ComparisonRow]) -> String? {
        guard rows.count > 1, let current = rows.first, let oldest = rows.last,
              let currentPace = current.secondsPerKilometer, let oldestPace = oldest.secondsPerKilometer else { return nil }
        let heartRateDelta = current.heartRate.flatMap { now in oldest.heartRate.map { now - $0 } }
        return ComparisonText.evolution(paceDelta: currentPace - oldestPace, heartRateDelta: heartRateDelta, oldestDate: oldest.dateText)
    }

    private static func deltaEvolution(_ comparison: WorkoutComparison, rows: [ComparisonRow]) -> String? {
        guard rows.count > 1, let oldest = rows.last, let currentPace = rows.first?.secondsPerKilometer,
              let speedDelta = comparison.activeSpeedDelta else { return nil }
        let currentSpeed = WorkoutConstants.metersPerKilometer / currentPace
        let oldestSpeed = currentSpeed - speedDelta
        guard oldestSpeed > 0 else { return nil }
        let paceDelta = currentPace - WorkoutConstants.metersPerKilometer / oldestSpeed
        return ComparisonText.evolution(paceDelta: paceDelta, heartRateDelta: comparison.activeHeartRateDelta, oldestDate: oldest.dateText)
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
