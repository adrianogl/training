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
    private(set) var summary: TodaySummary
    private(set) var readinessSentence = ""
    private(set) var readinessDay = ReadinessDay()
    private(set) var lastRun: LastRunSummary?

    init(context: ModelContext, today: Day) {
        self.today = today
        summary = (try? todaySummary(context: context, today: today)) ?? .empty
        readinessDay = Self.readinessDay(context: context, today: today, summary: summary)
        if let breakdown = summary.readiness, let verdict = summary.verdict {
            readinessSentence = TemplateInsightNarrator.readinessSentence(breakdown, verdict: verdict)
        }
        lastRun = Self.lastRun(context: context, id: summary.lastRunId)
    }

    func refreshSentence() async {
        guard let breakdown = summary.readiness, let verdict = summary.verdict else { return }
        let sentence = await makeInsightNarrator().readinessSentence(breakdown, verdict: verdict)
        guard !Task.isCancelled, !sentence.isEmpty else { return }
        readinessSentence = sentence
    }

    var raceTitle: String { summary.race.label }

    var raceDay: Day? {
        summary.raceCountdownDays.map { today.adding(days: $0) }
    }

    var countdownText: String? {
        TodayText.countdown(days: summary.raceCountdownDays, priority: summary.racePriority?.rawValue)
    }

    var goalSentence: String? {
        TodayText.goalSentence(
            crossing: summary.race.goalCrossing,
            goalSeconds: summary.race.goalSeconds,
            hasPrediction: summary.race.today != nil,
            raceDay: raceDay
        )
    }

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

    var predictionLines: [ChartLine] {
        let race = summary.race
        let from = today.adding(days: -C.predictionHistoryDays)
        let history = race.series.filter { $0.0 >= from }.map { ChartPoint(date: $0.0.chartDate, value: $0.1) }
        var lines = [ChartLine(name: "Previsão", colorKey: .prediction, dashed: false, points: history)]
        if !race.projection.isEmpty, let start = race.today {
            let projected = [ChartPoint(date: today.chartDate, value: start)] + race.projection.map { ChartPoint(date: $0.day.chartDate, value: $0.mid) }
            lines.append(ChartLine(name: "Previsão projetada", colorKey: .projection, dashed: true, points: projected))
        }
        return lines
    }

    var predictionBand: [ChartBandPoint] {
        summary.race.projection.map { ChartBandPoint(date: $0.day.chartDate, low: $0.low, high: $0.high) }
    }

    private func row(_ factor: ReadinessFactor) -> ReadinessFactorRowData {
        let name = C.componentNames[factor.component] ?? factor.component.rawValue
        guard let score = factor.todayScore else {
            return ReadinessFactorRowData(component: factor.component, name: name, detail: C.detailMissingValue, pointsText: nil, points: nil, group: .missing)
        }
        var parts = [actualValue(factor.component), "nota \(Int(score.rounded()))"]
        if let normal = factor.normalScore { parts.append("normal \(Int(normal.rounded()))") }
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

    private func actualValue(_ component: ReadinessComponent) -> String? {
        switch component {
        case .hrv:
            return readinessDay.hrv.map { "\(Int($0.rounded())) ms" }
        case .sleep:
            return readinessDay.sleepSeconds.map(TodayText.sleepDuration)
        case .bodyBattery:
            return readinessDay.bodyBattery.map { "\($0)" }
        case .load:
            return readinessDay.acuteChronic.map { "aguda:crônica \(TodayText.decimal($0, fractionDigits: 2))" }
        }
    }

    private static func readinessDay(context: ModelContext, today: Day, summary: TodaySummary) -> ReadinessDay {
        let iso = today.iso
        var descriptor = FetchDescriptor<DailyRecord>(predicate: #Predicate { $0.day == iso })
        descriptor.fetchLimit = 1
        let record = (try? context.fetch(descriptor))?.first
        return ReadinessDay(
            hrv: record?.hrvLastNight,
            sleepScore: summary.supporting.sleepScore,
            sleepSeconds: record?.sleepSeconds,
            bodyBattery: record?.bodyBatteryMorningMax,
            acuteChronic: summary.supporting.acuteChronic,
            stress: summary.supporting.stress
        )
    }

    private static func lastRun(context: ModelContext, id: Int64?) -> LastRunSummary? {
        guard let id else { return nil }
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        guard let record = records.first(where: { $0.activityId == id }) else { return nil }
        let analysis = WorkoutAnalysisContext.build(record: record, records: records, in: context)
        guard analysis.comparison != nil, !analysis.comparisonRows.isEmpty else {
            return LastRunSummary(
                activityId: id, title: record.workoutName ?? record.name, dateText: WorkoutListModel.dateText(record.start),
                comparisonTitle: "", rows: [], evolution: nil, evolutionOnDevice: false, notice: nil, showsTarget: false
            )
        }
        let reading = WorkoutReading.resolve(stored: record.narrativeData, assessment: analysis.assessment, blocks: analysis.blocks, evolution: analysis.evolution)
        return LastRunSummary(
            activityId: id,
            title: record.workoutName ?? record.name,
            dateText: WorkoutListModel.dateText(record.start),
            comparisonTitle: record.workoutName ?? WorkoutDetailConstants.similarRunsTitle,
            rows: analysis.comparisonRows,
            evolution: reading.evolution,
            evolutionOnDevice: reading.evolutionOnDevice,
            notice: analysis.comparisonNotice,
            showsTarget: analysis.hasPrescription
        )
    }
}
