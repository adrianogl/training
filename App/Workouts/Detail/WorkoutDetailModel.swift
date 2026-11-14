import FITReader
import Foundation
import Metrics
import Narrative
import Observation
import Storage
import SwiftData
import WorkoutAnalysis

@MainActor @Observable final class WorkoutDetailModel {
    let activityId: Int64
    private(set) var summary: WorkoutSummary?
    private(set) var isRun = false
    private(set) var hasPrescription = false
    private(set) var structureMissing = false
    private(set) var blocks: [WorkoutBlock] = []
    private(set) var bars: [BlockBar] = []
    private(set) var kilometers: BlockKilometers = [:]
    private(set) var kilometerBars: [Int: [BlockBar]] = [:]
    private(set) var assessment = WorkoutAssessment(positives: [], negatives: [], attention: [])
    private(set) var comparison: WorkoutComparison?
    private(set) var comparisonRows: [ComparisonRow] = []
    private(set) var comparisonTitle = ""
    private(set) var comparisonNotice: String?
    private(set) var evolutionText: String?
    private(set) var reading = WorkoutReading(findings: [], evolution: nil, findingsOnDevice: false, evolutionOnDevice: false)
    private(set) var route: [Coordinate] = []
    private(set) var heartRate: [(t: Double, bpm: Int)] = []
    private(set) var altitude: [(t: Double, meters: Double)] = []
    private(set) var zoneBands: [ZoneBand] = []
    private(set) var activeSpans: [BlockSpan] = []
    private(set) var zoneShares: [ZoneShare] = []
    private(set) var ruler: ZoneRulerData?
    private(set) var shareInput: WorkoutShareInput?
    private(set) var shareSource: ShareSource?
    private(set) var localDay: String?
    private(set) var completedCheck: CompletedCheck?
    private(set) var chatContext: WorkoutChatContext?
    private(set) var score: WorkoutScore?
    private(set) var scoreRows: [ScoreRowData] = []
    private(set) var trainingEffect: TrainingEffectData?

    init(activityId: Int64, context: ModelContext) {
        self.activityId = activityId
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        guard let record = records.first(where: { $0.activityId == activityId }) else { return }
        let analysis = WorkoutAnalysisContext.build(record: record, records: records, in: context)
        isRun = analysis.isRun
        hasPrescription = analysis.hasPrescription
        summary = Self.summary(record, isRun: isRun, hasPrescription: hasPrescription)
        zoneShares = Self.zoneShares(record.zoneSeconds)
        trainingEffect = TrainingEffectData(
            label: record.trainingEffectLabel,
            aerobic: record.aerobicTrainingEffect,
            anaerobic: record.anaerobicTrainingEffect,
            highZoneSeconds: record.zoneSeconds.count >= 5 ? WorkoutDetailConstants.highZoneIndices.reduce(0) { $0 + record.zoneSeconds[$1] } : nil,
            load: record.activityTrainingLoad
        )
        guard isRun else { return }
        structureMissing = analysis.structureMissing
        let samples = WorkoutAnalysisContext.samples(record)
        ruler = ZoneRulerData.make(
            watchZones: analysis.watchZones,
            watchSeconds: record.zoneSeconds,
            thresholdHeartRate: analysis.thresholdHeartRate,
            thresholdSeconds: Self.thresholdSeconds(record, threshold: analysis.thresholdHeartRate, samples: samples)
        )
        blocks = analysis.blocks
        kilometers = analysis.kilometers
        let scaled = BlockBarScale.bars(blocks, kilometers: kilometers, zones: analysis.zones)
        bars = scaled.blocks
        kilometerBars = scaled.kilometers
        route = ChartData.routePoints(Self.route(record))
        let fullHeartRate = ChartData.heartRateSeries(samples)
        heartRate = ChartData.thinned(fullHeartRate, limit: WorkoutDetailConstants.maxChartPoints) { Double($0.bpm) }
        altitude = ChartData.thinned(ChartData.altitudeSeries(samples), limit: WorkoutDetailConstants.maxChartPoints) { $0.meters }
        zoneBands = ChartData.zoneBands(analysis.zones, ceiling: Double(fullHeartRate.map { $0.bpm }.max() ?? 0))
        activeSpans = hasPrescription ? ChartData.activeSpans(blocks) : []

        score = analysis.score
        scoreRows = analysis.score.map(ScoreRows.rows) ?? []
        assessment = analysis.assessment
        comparison = analysis.comparison
        comparisonRows = analysis.comparisonRows
        comparisonNotice = analysis.comparisonNotice
        comparisonTitle = record.workoutName ?? WorkoutDetailConstants.similarRunsTitle
        reading = WorkoutReading.resolve(stored: record.narrativeData, assessment: assessment, blocks: blocks, evolution: analysis.evolution)
        evolutionText = reading.evolution
        shareInput = Self.shareInput(record, blocks: blocks, route: route, hasPrescription: hasPrescription, reading: reading, assessment: assessment)
        localDay = record.localDay
        if let meters = record.distance, meters > 0 {
            let kilometers = meters / WorkoutConstants.metersPerKilometer
            let average = (record.movingDuration ?? record.duration).map { $0 / kilometers }
            completedCheck = CompletedCheck(
                kilometers: kilometers,
                paceSecondsPerKm: (hasPrescription ? shareInput?.activePaceSecondsPerKm : nil) ?? average,
                averageHeartRate: record.averageHR,
                fadeSecondsPerKm: PlannedBriefingLoader.fade(samples)
            )
        }
        if let summary {
            let iso = record.localDay ?? ""
            var dailyDescriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == iso })
            dailyDescriptor.fetchLimit = 1
            chatContext = WorkoutChatContextBuilder.context(
                summary: summary, score: analysis.score?.value, analysis: analysisSummary, blocks: blocks,
                comparison: comparisonRows, daily: (try? context.fetch(dailyDescriptor))?.first, hasPrescription: hasPrescription
            )
        }
        shareSource = shareInput.map { input in
            ShareSourceBuilder.source(
                input: input, route: Self.route(record), samples: samples, zoneFloors: analysis.zones?.floors ?? [],
                blocks: blocks, comparisonRows: comparisonRows, analysis: analysisSummary
            )
        }
    }

    var analysisSummary: WorkoutAnalysisSummary {
        WorkoutFeedback.summary(assessment: assessment, blocks: blocks)
    }

    private static func shareInput(
        _ record: ActivityRecord,
        blocks: [WorkoutBlock],
        route: [Coordinate],
        hasPrescription: Bool,
        reading: WorkoutReading,
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
            readingLine: assessment.positives.isEmpty ? nil : reading.findings.first
        )
    }

    private static func thresholdSeconds(_ record: ActivityRecord, threshold: Int?, samples: [FITSample]) -> [Double] {
        guard let threshold else { return [] }
        if record.thresholdUsed == threshold { return record.thresholdZoneSeconds }
        return zoneSeconds(samples, zones: thresholdZones(thresholdHeartRate: threshold)) ?? []
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

    private static func summary(_ record: ActivityRecord, isRun: Bool, hasPrescription: Bool) -> WorkoutSummary {
        let row = WorkoutListModel.row(record)
        let kind = hasPrescription ? WorkoutConstants.plannedKind : isRun ? "Corrida livre" : record.name
        let subtitle = [kind == row.title ? nil : kind, record.locationName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return WorkoutSummary(
            title: row.title,
            dateText: row.dateText,
            subtitle: subtitle,
            distanceText: record.distance.flatMap { $0 > 0 ? $0 : nil }.map(WorkoutFormat.kilometers),
            durationText: row.durationText,
            paceText: row.paceText,
            averageHeartRateText: record.averageHR.map { "\(Int($0.rounded()))" },
            elevationText: record.elevationGain.map { "+\(Int($0.rounded())) m" },
            loadText: record.activityTrainingLoad.map { "\(Int($0.rounded()))" },
            hasPrescription: hasPrescription
        )
    }
}
