import Foundation
import Insights
import Metrics
import Narrative
import Observation
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

@MainActor @Observable final class TodayModel {
    typealias C = TodayConstants

    let today: Day
    @ObservationIgnored private let container: ModelContainer
    private(set) var summary: TodaySummary = .empty
    private(set) var readinessSentence = ""
    private(set) var readinessDay = ReadinessDay()
    private(set) var lastRun: LastRunSummary?
    private(set) var isLoaded = false

    init(container: ModelContainer, today: Day) {
        self.container = container
        self.today = today
    }

    func load() async {
        let container = container
        let today = today
        let result = await Task.detached(priority: .userInitiated) {
            Self.compute(container: container, today: today)
        }.value
        guard !Task.isCancelled else { return }
        summary = result.summary
        readinessDay = result.readinessDay
        lastRun = result.lastRun
        if let breakdown = result.summary.readiness, let verdict = result.summary.verdict {
            readinessSentence = TemplateInsightNarrator.readinessSentence(breakdown, verdict: verdict)
        }
        isLoaded = true
    }

    func refreshSentence() async {
        guard let breakdown = summary.readiness, let verdict = summary.verdict else { return }
        let sentence = await makeInsightNarrator().readinessSentence(breakdown, verdict: verdict)
        guard !Task.isCancelled, !sentence.isEmpty else { return }
        readinessSentence = sentence
    }

    var predictionContent: RacePredictionContent {
        RacePredictionContent(
            race: summary.race,
            today: today,
            countdownDays: summary.raceCountdownDays,
            priority: summary.racePriority?.rawValue,
            historyDays: C.predictionHistoryDays
        )
    }

    var raceTitle: String { summary.race.label }

    var raceDay: Day? {
        summary.raceCountdownDays.map { today.adding(days: $0) }
    }

    var goalSentence: String? { predictionContent.goalSentence }

    var readinessSummaryText: String? {
        summary.readiness.map { TodayText.readinessSummary(score: $0.score, normal: $0.normal) }
    }

    var factorRows: [ReadinessFactorRowData] {
        (summary.readiness?.factors ?? []).map(row)
    }

    var fitnessLines: [ChartLine] {
        let fitness = summary.fitness
        let history = fitness.history.suffix(C.fitnessHistoryDays)
        var lines = [
            ChartLine(name: "Fitness", colorKey: .fitness, dashed: false, points: history.map { ChartPoint(date: $0.day.chartDate, value: $0.fitness) }),
            ChartLine(name: "Forma", colorKey: .form, dashed: false, points: history.map { ChartPoint(date: $0.day.chartDate, value: $0.form) }),
        ]
        guard let last = history.last, !fitness.projection.isEmpty else { return lines }
        let projected = [last] + fitness.projection
        lines.append(ChartLine(name: "Fitness projetado", colorKey: .fitness, dashed: true, points: projected.map { ChartPoint(date: $0.day.chartDate, value: $0.fitness) }))
        lines.append(ChartLine(name: "Forma projetada", colorKey: .form, dashed: true, points: projected.map { ChartPoint(date: $0.day.chartDate, value: $0.form) }))
        return lines
    }

    private func row(_ factor: ReadinessFactor) -> ReadinessFactorRowData {
        let name = C.componentNames[factor.component] ?? factor.component.rawValue
        let raw = summary.readinessRaw[factor.component]
        guard factor.todayScore != nil else {
            return ReadinessFactorRowData(component: factor.component, name: name, detail: C.detailMissingValue, pointsText: nil, points: nil, group: .missing)
        }
        var parts: [String?] = [rawText(factor.component, raw?.today, includesLabel: true)]
        if factor.component == .sleep { parts.append(readinessDay.sleepSeconds.map(TodayText.sleepDuration)) }
        if let normal = raw?.normal, let text = rawText(factor.component, normal, includesLabel: false) {
            parts.append("seu normal \(text)")
        }
        if factor.component == .load { parts.append(C.loadIdealRange) }
        parts.append("peso \(Int((factor.weight * 100).rounded()))%")
        let group: ReadinessGroup = factor.points.map { $0 >= 0 ? .up : .down } ?? .baseline
        return ReadinessFactorRowData(
            component: factor.component,
            name: name,
            detail: parts.compactMap { $0 }.joined(separator: " · "),
            pointsText: factor.points.map { TodayText.signed($0, fractionDigits: 1) },
            points: factor.points,
            group: group
        )
    }

    private func rawText(_ component: ReadinessComponent, _ value: Double?, includesLabel: Bool) -> String? {
        guard let value else { return nil }
        switch component {
        case .hrv:
            return "\(Int(value.rounded())) ms"
        case .sleep:
            return includesLabel ? "nota \(Int(value.rounded()))" : "\(Int(value.rounded()))"
        case .bodyBattery:
            return "\(Int(value.rounded()))"
        case .load:
            let number = TodayText.decimal(value, fractionDigits: 2)
            return includesLabel ? "aguda:crônica \(number)" : number
        }
    }

    nonisolated private static func compute(container: ModelContainer, today: Day) -> TodayLoad {
        let context = ModelContext(container)
        try? freezeEveTargets(in: context, today: today)
        let summary = (try? todaySummary(context: context, today: today)) ?? .empty
        return TodayLoad(
            summary: summary,
            readinessDay: readinessDay(context: context, today: today, summary: summary),
            lastRun: lastRun(context: context, id: summary.lastRunId)
        )
    }

    nonisolated private static func readinessDay(context: ModelContext, today: Day, summary: TodaySummary) -> ReadinessDay {
        let iso = today.iso
        var descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == iso })
        descriptor.fetchLimit = 1
        let record = (try? context.fetch(descriptor))?.first
        return ReadinessDay(sleepSeconds: record?.sleepSeconds, stress: summary.supporting.stress)
    }

    nonisolated private static func lastRun(context: ModelContext, id: Int64?) -> LastRunSummary? {
        guard let id else { return nil }
        var target = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == id })
        target.fetchLimit = 1
        guard let record = (try? context.fetch(target))?.first else { return nil }
        let records = comparisonRecords(context: context, around: record)
        let analysis = WorkoutAnalysisContext.build(record: record, records: records, in: context)
        let title = record.workoutName ?? record.name
        let dateText = WorkoutListModel.dateText(record.start)
        guard analysis.comparison != nil, !analysis.comparisonRows.isEmpty else {
            return LastRunSummary(
                activityId: id, title: title, dateText: dateText,
                comparisonTitle: "", rows: [], evolution: nil, evolutionOnDevice: false, notice: nil, showsTarget: false,
                score: analysis.score?.value
            )
        }
        let reading = WorkoutReading.resolve(stored: record.narrativeData, assessment: analysis.assessment, blocks: analysis.blocks, evolution: analysis.evolution)
        return LastRunSummary(
            activityId: id,
            title: title,
            dateText: dateText,
            comparisonTitle: record.workoutName ?? WorkoutDetailConstants.similarRunsTitle,
            rows: analysis.comparisonRows,
            evolution: reading.evolution,
            evolutionOnDevice: reading.evolutionOnDevice,
            notice: analysis.comparisonNotice,
            showsTarget: analysis.hasPrescription,
            score: analysis.score?.value
        )
    }

    nonisolated private static func comparisonRecords(context: ModelContext, around record: ActivityRecord) -> [ActivityRecord] {
        let start = record.start
        let windowStart = start.addingTimeInterval(-TodayConstants.comparisonWindowDays * WorkoutDetailConstants.secondsPerDay)
        var recent = FetchDescriptor<ActivityRecord>(
            predicate: #Predicate { $0.start >= windowStart && $0.start <= start },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        recent.fetchLimit = TodayConstants.comparisonFetchLimit
        var records = (try? context.fetch(recent)) ?? []
        if let name = record.workoutName {
            var named = FetchDescriptor<ActivityRecord>(
                predicate: #Predicate { $0.workoutName == name && $0.start <= start },
                sortBy: [SortDescriptor(\.start, order: .reverse)]
            )
            named.fetchLimit = WorkoutDetailConstants.maxComparisons + 1
            let known = Set(records.map(\.activityId))
            records += ((try? context.fetch(named)) ?? []).filter { !known.contains($0.activityId) }
        }
        return records.sorted { $0.start > $1.start }
    }
}
